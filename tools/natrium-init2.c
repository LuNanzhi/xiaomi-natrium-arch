/* natrium-init.c - minimal static ARM64 init for bring-up diagnostics (v2)
 *
 * Why not busybox: the busybox found in the WSL container was an x86_64 shell
 * script with a self-referencing shebang, so the kernel could never exec /init
 * (=> "No working init found" => panic within seconds). This is a real static
 * ARM64 binary built with the cross toolchain; it uses syscalls directly.
 *
 * The report is written to three places, whichever works:
 *   1) cache partition as /natrium-diag.txt  (readable later from LineageOS)
 *   2) /dev/kmsg                             (kernel ring buffer)
 *   3) /dev/ttyGS0                           (USB ACM gadget => COM port on PC)
 *
 * Mode comes from the kernel cmdline, e.g. natrium.mode=logger:
 *   logger / diag : report, wait 20s, reboot
 *   flash         : report, wait 20s, power off
 *   stay          : report, then stay alive (heartbeat on serial, backlight on)
 *
 * Build: aarch64-linux-gnu-gcc -static -O2 -o init natrium-init.c
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define RPT_MAX (768 * 1024)
static char rpt[RPT_MAX];
static size_t rpt_len;

static void out(const char *s, size_t n)
{
    if (rpt_len + n < RPT_MAX) {
        memcpy(rpt + rpt_len, s, n);
        rpt_len += n;
    }
}

static void outf(const char *fmt, ...)
{
    char buf[4096];
    va_list ap;
    int n;
    va_start(ap, fmt);
    n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (n > 0)
        out(buf, (size_t)n);
}

static void write_file(const char *path, const char *val)
{
    int f = open(path, O_WRONLY | O_CLOEXEC);
    if (f < 0)
        return;
    (void)!write(f, val, strlen(val));
    close(f);
}

static void out_file(const char *path, const char *title)
{
    char buf[8192];
    int f = open(path, O_RDONLY | O_CLOEXEC);
    ssize_t r;
    outf("--- %s ---\n", title && *title ? title : path);
    if (f < 0) {
        outf("  (cannot open)\n");
        return;
    }
    while ((r = read(f, buf, sizeof(buf))) > 0)
        out(buf, (size_t)r);
    if (r <= 0)
        out("\n", 1);
    close(f);
}

static void out_dir(const char *path)
{
    DIR *d = opendir(path);
    struct dirent *e;
    outf("--- ls %s ---\n", path);
    if (!d) {
        outf("  (cannot open)\n");
        return;
    }
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.')
            continue;
        outf("  %s\n", e->d_name);
    }
    closedir(d);
}

static int mkdirs(const char *path)
{
    char tmp[512];
    size_t i, n;
    snprintf(tmp, sizeof(tmp), "%s", path);
    n = strlen(tmp);
    for (i = 1; i < n; i++) {
        if (tmp[i] == '/') {
            tmp[i] = 0;
            (void)mkdir(tmp, 0755);
            tmp[i] = '/';
        }
    }
    return mkdir(tmp, 0755);
}

/* locate the cache partition: by PARTNAME=cache, else by size (256MiB = 524288 sectors) */
static int find_cache(char *dev, size_t n)
{
    DIR *d = opendir("/sys/class/block");
    struct dirent *e;
    char path[512], buf[1024], size[64];
    int found = 0;
    if (!d)
        return 0;
    while ((e = readdir(d))) {
        int f;
        if (e->d_name[0] == '.')
            continue;
        snprintf(path, sizeof(path), "/sys/class/block/%s/uevent", e->d_name);
        f = open(path, O_RDONLY | O_CLOEXEC);
        if (f < 0)
            continue;
        buf[0] = 0;
        (void)!read(f, buf, sizeof(buf) - 1);
        close(f);
        if (strstr(buf, "PARTNAME=cache")) {
            snprintf(dev, n, "/dev/%s", e->d_name);
            found = 1;
            break;
        }
    }
    if (!found) {
        rewinddir(d);
        while ((e = readdir(d))) {
            int f;
            if (e->d_name[0] == '.')
                continue;
            snprintf(path, sizeof(path), "/sys/class/block/%s/size", e->d_name);
            f = open(path, O_RDONLY | O_CLOEXEC);
            if (f < 0)
                continue;
            size[0] = 0;
            (void)!read(f, size, sizeof(size) - 1);
            close(f);
            if (atoll(size) == 524288LL) {
                snprintf(dev, n, "/dev/%s", e->d_name);
                found = 1;
                break;
            }
        }
    }
    closedir(d);
    return found;
}

/* configure the USB controller as an ACM serial gadget (shows up as a COM port) */
static void setup_gadget(void)
{
    const char *G = "/sys/kernel/config/usb_gadget/natrium";
    char udc[128] = "";
    DIR *d;

    mkdirs("/sys/kernel/config");
    mount("configfs", "/sys/kernel/config", "configfs", 0, NULL);
    mkdirs("/sys/kernel/config/usb_gadget");
    if (mkdir(G, 0755) != 0 && access(G, F_OK) != 0) {
        outf("(cannot create configfs gadget)\n");
        return;
    }
    write_file("/sys/kernel/config/usb_gadget/natrium/idVendor", "0x18d1");
    write_file("/sys/kernel/config/usb_gadget/natrium/idProduct", "0xd001");
    mkdirs("/sys/kernel/config/usb_gadget/natrium/strings/0x409");
    write_file("/sys/kernel/config/usb_gadget/natrium/strings/0x409/serialnumber", "natrium");
    write_file("/sys/kernel/config/usb_gadget/natrium/strings/0x409/manufacturer", "Xiaomi");
    write_file("/sys/kernel/config/usb_gadget/natrium/strings/0x409/product", "natrium-diag");
    mkdirs("/sys/kernel/config/usb_gadget/natrium/configs/c.1/strings/0x409");
    write_file("/sys/kernel/config/usb_gadget/natrium/configs/c.1/strings/0x409/configuration", "acm");
    mkdirs("/sys/kernel/config/usb_gadget/natrium/functions/acm.usb0");
    (void)symlink("/sys/kernel/config/usb_gadget/natrium/functions/acm.usb0",
                  "/sys/kernel/config/usb_gadget/natrium/configs/c.1/acm.usb0");

    d = opendir("/sys/class/udc");
    if (d) {
        struct dirent *e;
        while ((e = readdir(d))) {
            if (e->d_name[0] == '.')
                continue;
            snprintf(udc, sizeof(udc), "%s", e->d_name);
            break;
        }
        closedir(d);
    }
    if (udc[0]) {
        write_file("/sys/kernel/config/usb_gadget/natrium/UDC", udc);
        outf("(gadget bound to UDC=%s)\n", udc);
    } else {
        outf("(no UDC found - USB controller did not come up)\n");
    }
}

int main(void)
{
    char cache_dev[128] = "", mode[64] = "logger", cmdline[4096];
    int f, r, sfd = -1;
    int i;

    mkdir("/proc", 0755);  mount("proc", "/proc", "proc", 0, NULL);
    mkdir("/sys", 0755);   mount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/dev", 0755);   mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
    mkdir("/tmp", 01777);
    mkdir("/mnt/cache", 0755);

    f = open("/proc/cmdline", O_RDONLY | O_CLOEXEC);
    if (f >= 0) {
        cmdline[0] = 0;
        r = (int)read(f, cmdline, sizeof(cmdline) - 1);
        close(f);
        if (r > 0) {
            char *p;
            cmdline[r] = 0;
            p = strstr(cmdline, "natrium.mode=");
            if (p) {
                p += strlen("natrium.mode=");
                for (r = 0; r < (int)sizeof(mode) - 1 && p[r] && p[r] != ' ' && p[r] != '\n'; r++)
                    mode[r] = p[r];
                mode[r] = 0;
            }
        }
    }

    /* earliest possible "I am alive" on the serial port */
    sfd = open("/dev/ttyGS0", O_WRONLY | O_NONBLOCK | O_CLOEXEC);

    outf("==========================================================\n");
    outf("  natrium mainline bring-up init (static ARM64) is running\n");
    outf("  mode = %s\n", mode);
    outf("==========================================================\n");
    if (sfd >= 0) {
        const char *hello = "\r\n[natrium-init] running, collecting info...\r\n";
        (void)!write(sfd, hello, strlen(hello));
    }

    out_file("/proc/cmdline", "cmdline");
    out_file("/proc/version", "uname");
    out_file("/proc/partitions", "partitions");
    out_dir("/sys/class/block");
    out_dir("/sys/class/drm");
    out_dir("/sys/class/backlight");
    out_dir("/sys/class/leds");
    out_dir("/sys/class/udc");
    out_file("/sys/class/drm/card0-DSI-1/status", "drm card0-DSI-1 status");
    out_file("/proc/device-tree/model", "device-tree model");

    if (find_cache(cache_dev, sizeof(cache_dev))) {
        if (mount(cache_dev, "/mnt/cache", "ext4", 0, NULL) == 0 ||
            mount(cache_dev, "/mnt/cache", "f2fs", 0, NULL) == 0) {
            outf("(cache mounted: %s)\n", cache_dev);
            f = open("/mnt/cache/natrium-diag.txt", O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
            if (f >= 0) {
                (void)!write(f, rpt, rpt_len);
                fsync(f);
                close(f);
            }
        } else {
            outf("(cache partition %s mount failed)\n", cache_dev);
        }
    } else {
        outf("(cache partition not found - storage did not come up)\n");
    }

    /* backlight + LEDs to maximum (visible signal) */
    {
        DIR *d = opendir("/sys/class/backlight");
        struct dirent *e;
        if (d) {
            while ((e = readdir(d))) {
                char p[512];
                if (e->d_name[0] == '.')
                    continue;
                snprintf(p, sizeof(p), "/sys/class/backlight/%s/brightness", e->d_name);
                write_file(p, "255");
            }
            closedir(d);
        }
        d = opendir("/sys/class/leds");
        if (d) {
            while ((e = readdir(d))) {
                char p[512];
                if (e->d_name[0] == '.')
                    continue;
                snprintf(p, sizeof(p), "/sys/class/leds/%s/brightness", e->d_name);
                write_file(p, "255");
            }
            closedir(d);
        }
    }

    setup_gadget();
    for (i = 0; i < 40 && access("/dev/ttyGS0", F_OK) != 0; i++)
        usleep(250000);
    if (sfd < 0)
        sfd = open("/dev/ttyGS0", O_WRONLY | O_NONBLOCK | O_CLOEXEC);

    /* kernel ring buffer */
    {
        static char kbuf[512 * 1024];
        long n;
        outf("\n===== dmesg =====\n");
        n = syscall(SYS_syslog, 3, kbuf, sizeof(kbuf) - 1);
        if (n > 0) {
            kbuf[n] = 0;
            out(kbuf, (size_t)n);
        } else {
            outf("(syslog read failed: %ld)\n", n);
        }
    }

    f = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (f >= 0) {
        (void)!write(f, rpt, rpt_len);
        close(f);
    }
    if (sfd >= 0) {
        (void)!write(sfd, "\r\n===== REPORT BEGIN =====\r\n", 28);
        (void)!write(sfd, rpt, rpt_len);
        (void)!write(sfd, "\r\n===== REPORT END =====\r\n", 26);
    }

    if (!strcmp(mode, "stay")) {
        for (i = 0;; i++) {
            char hb[160];
            int n;
            if (sfd >= 0) {
                /* re-send the whole report every 30s: data written to a CDC-ACM
                 * port before the host opens it is lost, so repeat it. */
                (void)!write(sfd, "\r\n===== REPORT BEGIN =====\r\n", 28);
                (void)!write(sfd, rpt, rpt_len);
                n = snprintf(hb, sizeof(hb), "\r\n===== REPORT END (heartbeat %d, kernel still alive) =====\r\n", i);
                (void)!write(sfd, hb, (size_t)n);
            }
            sleep(30);
        }
    }
    sleep(20);
    if (!strcmp(mode, "flash")) {
        sync();
        reboot(RB_POWER_OFF);
    }
    sync();
    reboot(RB_AUTOBOOT);
    for (;;)
        sleep(3600);
    return 0;
}
