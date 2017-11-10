#include <execinfo.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>

#define STACKTRACES 10


static char *exec_path = NULL;


void bt_set_arg0(const char *arg0) {
	if (!exec_path && arg0) {
		exec_path = strdup(arg0);
	}
}

static void addr_to_array(char **strings, size_t siz, char **result) {
	char *start, *end;

	for (size_t i = 0; i < siz; ++i) {
		start = strchr(strings[i], '+');
		if (start) {
			end = strchr(start, ')');
			start++;
			if (end)
				result[i] = strndup(start, end-start);
			else
				result[i] = strdup("");
		}
	}
}

void bt_print_trace (void) {
	void *array[STACKTRACES];
	size_t bt_size;
	char **strings;
	size_t i;
	char **addrs;

	bt_size = backtrace(array, STACKTRACES);
	strings = backtrace_symbols(array, bt_size);

	printf("\n\n[1] Obtained %zd stack frames.\n", bt_size);
	for (i = 0; i < bt_size; ++i)
		printf("%s\n", strings[i]);

	/* addr2line -p -e ./btrace -f -i [addresses] */
	if (exec_path) {
		addrs = (char**) calloc(bt_size, sizeof(*addrs));

		addr_to_array(strings, bt_size, addrs);
		printf("\n\n[2] Run for more info: addr2line -p -e %s -f -i", exec_path);
		for (i = 0; i < bt_size; ++i) {
			printf(" %s", addrs[i]);
		}
		printf("%s\n", "");

		for (i = 0; i < bt_size; ++i)
			if (addrs[i])
				free(addrs[i]);
		free(addrs);
	}

	free(strings);
}

void bt_sighandler(int signum) {
	bt_print_trace();
	switch (signum) {
		case SIGTERM:
		case SIGABRT:
		case SIGSEGV:
			exit(1);
	}
}




/* A dummy function to make the backtrace more interesting. */
void dummy_function(void) {
	bt_print_trace();
}

#include <assert.h>
int main(int argc, char **argv) {
	bt_set_arg0(argv[0]);
	dummy_function();
	signal(SIGTERM, bt_sighandler);
	signal(SIGABRT, bt_sighandler);
	signal(SIGSEGV, bt_sighandler);

	//assert(0);
	*(int*)(NULL) = 0;
	return 0;
}
