#define _GNU_SOURCE
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <sched.h>
#include <string.h>
#include <libgen.h>
#include <time.h>
#include <sys/mount.h>
#include <sys/ptrace.h>
#include "lua/lua.h"
#include "lua/lauxlib.h"
#include "lua/lualib.h"
#include <fcntl.h>

#define RETURN_ERROR return __LINE__

static int child_run=0;
static int* global_argc;
static char*** global_argv;

void child_wait(char* name)
{
	while (!child_run)
	{
		usleep(1000);
	}
}

int lua_exec_callback(const char* function, lua_State *L)
{
	/* push functions and arguments */
	if (!lua_getglobal(L, function))
	{
		printf("unable to find function `%s'\n", function);
		RETURN_ERROR;
	}

	/* do the call (0 arguments, 1 result) */
	if (lua_pcall(L, 0, 1, 0) != 0)
		error(L, "error running callback `f': %s",
			function);

	/* retrieve result */
	if (!lua_isnumber(L, -1))
	{
		printf("function `%s' must return a number (0 for sucess, anything else for failure)\n", function);
		lua_pop(L, 1);
		RETURN_ERROR;
	}
	double z = lua_tonumber(L, -1);
	lua_pop(L, 1);  /* pop returned value */
	return z;
}

int lua_exec_callback_arg(const char* function, lua_State *L, int arg)
{
	/* push functions and arguments */
	if (!lua_getglobal(L, function))
	{
		printf("unable to find function `%s'\n", function);
		RETURN_ERROR;
	}

	lua_pushnumber(L, arg);

	/* do the call (1 arguments, 1 result) */
	if (lua_pcall(L, 1, 1, 0) != 0)
		error(L, "error running callback `f': %s",
			function);

	/* retrieve result */
	if (!lua_isnumber(L, -1))
	{
		printf("function `%s' must return a number (0 for sucess, anything else for failure)\n", function);
		lua_pop(L, 1);
		RETURN_ERROR;
	}
	double z = lua_tonumber(L, -1);
	lua_pop(L, 1);  /* pop returned value */
	return z;
}

const char* base_path(lua_State *L)
{
	static char base_path[PATH_MAX];
	lua_getglobal(L, "base_path");
	strcpy(base_path, lua_tostring(L,-1));
	lua_pop(L,1);
	return base_path;
}

const char* root_path(lua_State *L)
{
	static char root_path[PATH_MAX];
	lua_getglobal(L, "base_path");
	strcpy(root_path, lua_tostring(L,-1));
	strcpy(root_path + strlen(root_path), ".jail/");
	lua_pop(L,1);
	return root_path;
}

static pid_t container_pid=0;

int cleanup_pid(lua_State *L)
{
	container_pid=0;
	const char* basepath = base_path(L);
	char* pidfile_path = malloc(strlen(basepath) + 100);
	sprintf(pidfile_path, "%s/.pid", basepath);
	unlink(pidfile_path);
	return 0;
}

int write_pid(lua_State *L, pid_t pid)
{
	container_pid = pid;
	const char* basepath = base_path(L);
	char* pidfile_path = malloc(strlen(basepath) + 100);
	sprintf(pidfile_path, "%s/.pid", basepath);
	FILE* pidfile = fopen(pidfile_path, "w");
	if (pidfile)
	{
		fprintf(pidfile, "%u\n", pid);
		fclose(pidfile);
	}
	return 0;
}

pid_t get_container_pid(lua_State *L)
{
	const char* basepath = base_path(L);
	char* pidfile_path = malloc(strlen(basepath) + 100);
	sprintf(pidfile_path, "%s/.pid", basepath);
	FILE* pidfile = fopen(pidfile_path, "r");
	if (pidfile)
	{
		fscanf(pidfile, "%u", &container_pid);
		fclose(pidfile);
	}
	return container_pid;
}

int is_running(lua_State *L, pid_t child)
{
	pid_t pid=0;
	if (child)
	{
		pid=child;
	}
	else
	{
		pid=get_container_pid(L);
	}
	if (pid && !kill(pid, 0))
	{
		return 1;
	}
	return 0;
}

int init_environment(lua_State* L, const char writeable)
{
	int argx;
	for (argx=1; argx<*global_argc; argx++)
		memset(global_argv[0][argx], 0, strlen(global_argv[0][argx]));

	const char* container_root = base_path(L);
	char* target = malloc(strlen(container_root) + 100);

	sprintf(target, "%s", container_root);
	mkdir(target, 0777);

	sprintf(target, "%s.filesystem", container_root);
	mkdir(target, 0777);

	sprintf(target, "%s.jail", container_root);
	mkdir(target, 0777);

	sprintf(target, "%s", container_root);
	chdir(target);

	int ret = lua_exec_callback_arg("mount_container", L, writeable);
	if (ret)
	{
		printf("Error %d initialising container\n", ret);
		return ret;
	}
	sprintf(target, "%s.jail", container_root);
	chdir(target);
	return 0;
}

int init_network_host(lua_State *L, pid_t pid)
{
	return lua_exec_callback_arg("init_network_host", L, pid);
}

int init_network_child(lua_State *L)
{
	int ret;
	if (init_network_needed(L))
		ret = lua_exec_callback("init_network_child", L);
	else
		return 0;
	if (ret)
		printf("Error %d initialising network\n", ret);
	return ret;
}

int init_network_needed(lua_State *L)
{
	return lua_exec_callback("init_network_needed", L);
}

int build_clean(void* args)
{
	child_wait("clean");
	
	lua_State *L = (lua_State*)args;
	const char* container_root = base_path(L);
	char* target = malloc(strlen(container_root) + 100);
	sprintf(target, "rm -rf %s/.[!.]*", container_root);
	system(target);
	free(target);
	return 0;
}

int build(void* args)
{
	child_wait("build");

	printf("Building container...\n");
	lua_State *L = (lua_State*)args;
	int ret = init_environment(L, 1);
	if (ret)
		return ret;
	if (init_network_needed(L))
		ret = init_network_child(L);
	if (ret)
		return ret;
	return lua_exec_callback("build", L);
}

int need_build(void* args)
{
	lua_State *L = (lua_State*)args;
	int ret = init_environment(L, 1);
	if (ret)
		return ret;
	return lua_exec_callback("need_build", L);
}

int start(void* args)
{
	child_wait("start");
	setsid();
	unlink("../console");
	if (mknod("../console", 010755, 0) < 0)
		RETURN_ERROR;
	int fd;
	if (( fd = open("../console", O_RDWR )) < 0)
		RETURN_ERROR;
	dup2(fd, 0);
	dup2(fd, 1);
	dup2(fd, 2);

	lua_State *L = (lua_State*)args;
	int ret = init_environment(L, 0);
	if (ret)
		return ret;
	ret = init_network_child(L);
	if (ret)
		return ret;
	chroot(".");
	ret = lua_exec_callback("apply_config", L);
	if (ret)
	{
		printf("Error %d applying config\n", ret);
		return ret;
	}
	ret = lua_exec_callback("lock_container", L);
	if (ret)
	{
		printf("Error %d making container read only\n", ret);
		return ret;
	}
	return lua_exec_callback("run", L);
}

int shell(void* args)
{
	child_wait("shell");

	lua_State *L = (lua_State*)args;
	int ret = init_environment(L, 0);
	if (ret)
		return ret;
	ret = init_network_child(L);
	if (ret)
		return ret;
	chroot(".");
	ret = lua_exec_callback("apply_config", L);
	if (ret)
	{
		printf("Error %d applying config\n", ret);
		return ret;
	}
	return lua_exec_callback("shell", L);
}

void print_usage(const char* config_file)
{
	if (config_file && strstr(config_file, "/"))
		printf("Usage: %s <command>\n", config_file);
	else
		printf("Usage: container <config> <command>\n");
	printf("Commands:\n");
	printf("\tbuild\t(Re)Builds the container\n");
	printf("\tclean\tPurges the container\n");
	printf("\tstart\tStarts the container\n");
	printf("\tstop\tStops the container\n");
	printf("\trestart\tRestarts the container\n");
	printf("\tshell\tLaunches a shell inside the container environment\n");
}

void RESUME(pid_t pid)
{
	kill(pid, SIGUSR2);
}

int SPAWN(int (*function)(void *), lua_State *L)
{
	long flags = CLONE_NEWPID|CLONE_NEWNS|SIGCHLD;
	if (init_network_needed(L))
		flags |= CLONE_NEWNET;
	char stack[4096];
	child_run = 0;
	int tid = clone(function, stack + sizeof(stack), flags, L);
	if (tid== -1)
	{
		perror("exec");
		RETURN_ERROR;
	}
	if (init_network_needed(L))
	{
		int ret = init_network_host(L, tid);
		if (ret)
			return 0;
	}
	RESUME(tid);
	write_pid(L, tid);
	return tid;
}

int ISOLATE(int (*function)(void *), lua_State *L)
{
	pid_t tid = SPAWN(function, L);
	int status=0;
	while (is_running(L, tid))
	{
		waitpid(tid, &status, NULL);
	}
	cleanup_pid(L);
	int ret = WEXITSTATUS(status);
	return ret;
}

void sig_handler(int sig)
{
	if (sig == SIGUSR2)
	{
		child_run=1;
	}
	else
	{
		if (container_pid)
		{
			kill(container_pid, SIGKILL);
		}
		exit(-1);
	}
}

extern char embedded_lua_ptr[]      asm("_binary_container_lua_start");
extern char embedded_lua_ptr_end[]      asm("_binary_container_lua_end");

int main (int argc, char* argv[]) {
	global_argc = &argc;
	global_argv = &argv;

	char* embedded_lua = malloc(embedded_lua_ptr_end - embedded_lua_ptr + 2);
	memcpy(embedded_lua, embedded_lua_ptr, embedded_lua_ptr_end - embedded_lua_ptr + 2);
	
	signal(SIGKILL, sig_handler);
	signal(SIGABRT, sig_handler);
	signal(SIGINT, sig_handler);
	signal(SIGUSR2, sig_handler);
	char command[PATH_MAX];
	char filename[PATH_MAX];
	char base_directory[PATH_MAX];

	unshare(CLONE_FS|CLONE_NEWIPC|CLONE_NEWNS|CLONE_NEWUTS);

	lua_State *L = luaL_newstate();   /* opens Lua */
	luaL_openlibs(L);
	if (argc < 2)
	{
		print_usage(NULL);
		RETURN_ERROR;
	}

	if (argc < 3)
	{
		print_usage(argv[1]);
		RETURN_ERROR;
	}

	realpath(argv[1],filename);
	strcpy(command,argv[2]);

	char* container_path = dirname(strdup(filename));
	char* container_name = filename + (strlen(container_path)+1);
	char* lua_path = malloc(strlen(container_path)*2+100);
	sprintf(base_directory, "%s/.%s/", container_path, container_name);
	sprintf(lua_path, "%s/?;%s/?.lua;/etc/container/?.lua", container_path, container_path);

	lua_pushstring(L, filename);
	lua_setglobal(L, "config");
	lua_pushstring(L, base_directory);
	lua_setglobal(L, "base_path");
	lua_pushstring(L, container_path);
	lua_setglobal(L, "container_path");
	lua_pushstring(L, root_path(L));
	lua_setglobal(L, "root_path");

	lua_getglobal( L, "package" );
	lua_pushstring( L, lua_path);
	lua_setfield( L, -2, "path" );
	lua_pop( L, 1 );
	
	if (luaL_loadstring(L, embedded_lua) || lua_pcall(L, 0, 0, 0))
		error(L, "cannot run container: %s",
			lua_tostring(L, -1));
	if (luaL_loadfile(L, filename) || lua_pcall(L, 0, 0, 0))
		error(L, "cannot run container: %s",
			lua_tostring(L, -1));
	char done_something=0;
	int ret=0;
	if (!ret && !strcmp(command, "clean") || !strcmp(command, "build"))
	{
		if (is_running(L, 0))
		{
			printf("Terminate container first.\n");
			RETURN_ERROR;
		}
		ret = ISOLATE(build_clean, L);
		done_something = 1;
	}
	if (!ret && !strcmp(command, "build"))
	{
		if (is_running(L, 0))
		{
			printf("Container already running.\n");
			RETURN_ERROR;
		}
		ret = ISOLATE(build, L);
		done_something = 1;
	}
	if (!ret && !strcmp(command, "restart") || !strcmp(command, "stop"))
	{
		pid_t pid = get_container_pid(L);
		time_t start = time(NULL);
		while (pid && !kill(pid, SIGKILL) && start > time(NULL) - 10)
		{
			usleep(100000);
		}
		if (is_running(L, pid))
		{
			printf("Unable to stop container.\n");
			RETURN_ERROR;
		}
		printf("Container terminated.\n");
		done_something = 1;
	}
	if (!ret && !strcmp(command, "restart") || !strcmp(command, "start"))
	{
		if (is_running(L, 0))
		{
			printf("Container already running.\n");
			RETURN_ERROR;
		}
		if (need_build(L))
		{
			printf("Container needs to be built first.\n");
			ret = ISOLATE(build, L);
			if (ret)
				return ret;
		}
		SPAWN(start, L);
		if (is_running(L, 0))
			printf("Container running\n");
		else
			RETURN_ERROR;
		done_something = 1;
	}
	if (!ret && !strcmp(command, "shell"))
	{
		if (is_running(L, 0))
		{
			printf("Container already running.\n");
			RETURN_ERROR;
		}
		if (need_build(L))
		{
			printf("Error: Container not built.\n");
			RETURN_ERROR;
		}
		printf("Launching Shell\n");
		ISOLATE(shell, L);
		done_something = 1;
	}
	if (!ret && !done_something)
		print_usage(argv[1]);
	lua_close(L);
	return 0;
}
