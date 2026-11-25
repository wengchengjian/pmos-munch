#include <linux/gpio.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
	if (argc < 5) {
		fprintf(stderr, "usage: %s chip line value seconds\n", argv[0]);
		return 2;
	}
	int chip = atoi(argv[1]);
	int line = atoi(argv[2]);
	int val = atoi(argv[3]);
	int secs = atoi(argv[4]);
	char path[64];
	snprintf(path, sizeof path, "/dev/gpiochip%d", chip);
	int fd = open(path, O_RDWR | O_CLOEXEC);
	if (fd < 0) { perror("open"); return 1; }
	struct gpiohandle_request req;
	memset(&req, 0, sizeof req);
	req.lineoffsets[0] = line;
	req.flags = GPIOHANDLE_REQUEST_OUTPUT;
	req.default_values[0] = val ? 1 : 0;
	req.lines = 1;
	strncpy(req.consumer_label, "munch-blank", sizeof(req.consumer_label) - 1);
	if (ioctl(fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0) { perror("ioctl"); return 1; }
	printf("ok chip%d line%d=%d hold %ds\n", chip, line, val, secs);
	fflush(stdout);
	sleep(secs);
	return 0;
}
