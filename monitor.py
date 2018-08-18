#!/usr/bin/python3

import datetime
import json
import logging
import os
import re
import subprocess
import sys
import tempfile
import time
from watchdog.observers import Observer
from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler

RUNAS = "/files/runas.sh"

#-----------------------------------------------------------------------------------------------------------------------

def remove_linefeeds(input_filename):
    temp = tempfile.NamedTemporaryFile(delete=False)

    with open(input_filename, "r") as input_file:
        with open(temp.name, "w") as output_file:
            for line in input_file:
                output_file.write(line)

    return temp.name

#-----------------------------------------------------------------------------------------------------------------------

def to_seconds(timestr):
    hms = timestr.split(':')

    seconds = 0

    while hms:
        seconds *= 60
        seconds += int(hms.pop(0))

    return seconds

#-----------------------------------------------------------------------------------------------------------------------

def read_config(config_file):
    config_file = remove_linefeeds(config_file)

    # Shenanigans to read docker env vars, and the bash format config file. I didn't want to ask them to change their
    # config files.
    dump_command = '{} -c "import os, json;print(json.dumps(dict(os.environ)))"'.format(sys.executable)

    pipe = subprocess.Popen(['/bin/bash', '-c', dump_command], stdout=subprocess.PIPE)
    string = pipe.stdout.read().decode('ascii')
    base_env = json.loads(string)

    source_command = 'source {}'.format(config_file)
    pipe = subprocess.Popen(['/bin/bash', '-c', 'set -a && {} && {}'.format(source_command,dump_command)],
        stdout=subprocess.PIPE)
    string = pipe.stdout.read().decode('ascii')
    config_env = json.loads(string)

    env = config_env.copy()
    env.update(base_env)

    class Args:
        pass

    args = Args()

    if "WATCH_DIR" not in env:
        logging.error("Configuration error. WATCH_DIR must be defined.")
        sys.exit(1)

    if not os.path.isdir(env["WATCH_DIR"]):
        logging.error("Configuration error. WATCH_DIR must be a directory.")
        sys.exit(1)
    args.watch_dir = env["WATCH_DIR"]

    if "SETTLE_DURATION" not in env or not re.match("([0-9]{1,2}:){0,2}[0-9]{1,2}", env["SETTLE_DURATION"]):
        logging.error("Configuration error. SETTLE_DURATION must be defined as HH:MM:SS or MM:SS or SS.")
        sys.exit(1)
    args.settle_duration = to_seconds(env["SETTLE_DURATION"])

    if "MAX_WAIT_TIME" not in env or not re.match("([0-9]{1,2}:){0,2}[0-9]{1,2}", env["MAX_WAIT_TIME"]):
        logging.error("Configuration error. MAX_WAIT_TIME must be defined as HH:MM:SS or MM:SS or SS.")
        sys.exit(1)
    args.max_wait_time = to_seconds(env["MAX_WAIT_TIME"])

    if args.settle_duration > args.max_wait_time:
        logging.error("Configuration error. SETTLE_DURATION cannot be greater than MAX_WAIT_TIME.")
        sys.exit(1)

    if "MIN_PERIOD" not in env or not re.match("([0-9]{1,2}:){0,2}[0-9]{1,2}", env["MIN_PERIOD"]):
        logging.error("Configuration error. MIN_PERIOD must be defined as HH:MM:SS or MM:SS or SS.")
        sys.exit(1)
    args.min_period = to_seconds(env["MIN_PERIOD"])

    if "USER_ID" not in env or not re.match("[0-9]{1,}", env["USER_ID"]):
        logging.error("Configuration error. USER_ID must be a whole number.")
        sys.exit(1)
    args.user_id = env["USER_ID"]

    if "GROUP_ID" not in env or not re.match("[0-9]{1,}", env["GROUP_ID"]):
        logging.error("Configuration error. GROUP_ID must be a whole number.")
        sys.exit(1)
    args.group_id = env["GROUP_ID"]

    if "COMMAND" not in env:
        logging.error("Configuration error. COMMAND must be defined.")
        sys.exit(1)
    args.command = env["COMMAND"]

    if "UMASK" not in env or not re.match("0[0-7]{3}", env["UMASK"]):
        logging.error("Configuration error. UMASK must be defined as an octal 0### number.")
        sys.exit(1)
    args.umask = env["UMASK"]

    if "DEBUG" in env and not re.match("[01]", env["DEBUG"]):
        logging.error("Configuration error. DEBUG must be defined as 0 or 1.")
        sys.exit(1)
    args.debug = "DEBUG" in env and env["DEBUG"] == "1"

    if "IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING" not in env or not re.match("[01]", env["IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING"]):
        logging.error("Configuration error. IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING must be defined as 0 or 1.")
        sys.exit(1)
    args.ignore_events_while_command_is_running = env["IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING"] == "1"

    if "USE_POLLING" in env:
        if not re.match("(yes|no|true|false|0|1)", env["USE_POLLING"], re.IGNORECASE):
            logging.error("Configuration error. USE_POLLING must be \"yes\" or \"no\".")
            sys.exit(1)

        args.use_polling = True if re.match("(yes|true|1)", env["USE_POLLING"], re.IGNORECASE) else False
    else:
        args.use_polling = False

    logging.info("CONFIGURATION:")
    logging.info("      WATCH_DIR=%s", args.watch_dir)
    logging.info("SETTLE_DURATION=%s", args.settle_duration)
    logging.info("  MAX_WAIT_TIME=%s", args.max_wait_time)
    logging.info("     MIN_PERIOD=%s", args.min_period)
    logging.info("        COMMAND=%s", args.command)
    logging.info("        USER_ID=%s", args.user_id)
    logging.info("       GROUP_ID=%s", args.group_id)
    logging.info("          UMASK=%s", args.umask)
    logging.info("          DEBUG=%s", args.debug)
    logging.info("    USE_POLLING=%s", args.use_polling)
    logging.info("IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=%s", args.ignore_events_while_command_is_running)

    return args

#-----------------------------------------------------------------------------------------------------------------------

# This is the main watchdog class. When a new event is detected, the class keeps track of the time since that event was
# detected, as well as the time since any event was detected. After being reset, it starts looking for a new event
# again.
#
# This class runs in parallel with the rest of the program, so we shouldn't be missing any events due to not listening
# at the time.
class ModifyHandler(FileSystemEventHandler):
    _detected_event, _detected_time, _last_event_time, _enabled = None, None, None, True

    def on_any_event(self, event):
        if not self._enabled:
            return

        # Ignore changes to the watch dir itself. event.src_path doesn't exist for delete events
        if os.path.exists(event.src_path) and os.path.samefile(args.watch_dir, event.src_path):
            return

        self._last_event_time = datetime.datetime.now()

        if not self._detected_event:
            self._detected_event = event
            self._detected_time = self._last_event_time

    def enable_monitoring(self, enabled):
        self._enabled = enabled

    def detected_event(self):
        return self._detected_event

    def reset(self):
        self._detected_event = None
        self._detected_time = None

    def time_since_detected(self):
        return (datetime.datetime.now() - self._detected_time).total_seconds()

    def time_since_last_event(self):
        return (datetime.datetime.now() - self._last_event_time).total_seconds()

#-----------------------------------------------------------------------------------------------------------------------

def run_command(args, event_handler):
    # Reset before, in case IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING is set, and new events come in while the command is
    # running
    event_handler.reset()

    logging.info("Running command with user ID %s, group ID %s, and umask %s", args.user_id, args.group_id, args.umask)
    logging.info("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv")

    event_handler.enable_monitoring(not args.ignore_events_while_command_is_running)
    returncode = subprocess.call([RUNAS, args.user_id, args.group_id, args.umask, args.command])
    event_handler.enable_monitoring(True)

    logging.info("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    logging.info("Finished running command. Exit code was %i", returncode)

#-----------------------------------------------------------------------------------------------------------------------

def wait_for_change(event_handler):
    logging.info("Waiting for new change")
            
    while True:
        event = event_handler.detected_event()

        if event:
            logging.info("Detected change to %s %s", "directory" if event.is_directory else "file", event.src_path)
            return

        time.sleep(.1)

#-----------------------------------------------------------------------------------------------------------------------

def wait_for_events_to_stabilize(settle_duration, max_wait_time, event_handler):
    logging.info("Waiting for watch directory to stabilize for %i seconds before triggering command", settle_duration)

    while True:
        if event_handler.time_since_last_event() >= settle_duration:
            logging.info("Watch directory stabilized for %s seconds. Triggering command.", settle_duration)
            return
        elif event_handler.time_since_detected() >= max_wait_time:
            logging.warn("WARNING: Watch directory didn't stabilize for %s seconds. Triggering command anyway.",
                    max_wait_time)
            return

        time.sleep(.1)

#-----------------------------------------------------------------------------------------------------------------------

def block_until_min_period(min_period, last_command_run):
    seconds_since_last_run = (datetime.datetime.now() - last_command_run).total_seconds()

    if seconds_since_last_run >= min_period:
        return

    logging.info("Command triggered, but it's too soon to run the command again. Waiting another %i seconds",
            args.min_period - seconds_since_last_run)

    time.sleep(min_period - seconds_since_last_run)

#-----------------------------------------------------------------------------------------------------------------------

config_file = sys.argv[1]

name = os.path.splitext(os.path.basename(config_file))[0]

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] {}: %(message)s'.format(name), datefmt='%Y-%m-%d %H:%M:%S')

args = read_config(config_file)

#args["DEBUG"] = True

if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)


logging.info("Starting monitor for %s", name)

# Launch the watchdog
if args.use_polling:
    logging.info("Using polling to detect changes")
    observer = PollingObserver()
else:
    logging.info("Using native change detection to detect changes")
    observer = Observer()

event_handler = ModifyHandler()
observer.schedule(event_handler, args.watch_dir, recursive=True)
observer.start()

try:
    # Initialize this to some time in the past
    last_command_run = datetime.datetime.now() - datetime.timedelta(seconds=args.min_period+10)

    # To help keep myself sane. "waiting for change" -> "waiting to stabilize or time out" -> "command triggered" ->
    # "command running" -> "waiting for change". We can also go from "command triggered" -> "waiting to stabilize or
    # time out", if new changes are detected while we're waiting for the min_period to expire.
    state = "waiting for change"

    while True:
        # Need to put an "if" on this state because the loop can restart if new changes are detected while waiting for
        # min_period to expire.
        if state == "waiting for change":
            wait_for_change(event_handler)
            state = "waiting to stabilize or time out"

        wait_for_events_to_stabilize(args.settle_duration, args.max_wait_time, event_handler)
        state = "command triggered"

        block_until_min_period(args.min_period, last_command_run)

        # In case new events came in while we were sleeping. (But skip this if we've already waited our max_wait_time)
        if event_handler.time_since_last_event() < args.settle_duration and \
                event_handler.time_since_detected() < args.max_wait_time:
            logging.info("Detected new changes while waiting.")
            state = "waiting to stabilize or time out"
            continue

        state = "command running"
        run_command(args, event_handler)
        last_command_run = datetime.datetime.now()
        state = "waiting for change"
except KeyboardInterrupt:
    observer.stop()

observer.join()

sys.exit(0)
