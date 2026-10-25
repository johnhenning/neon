"""Capture filtered simulator focus diagnostics for a bounded UI journey."""
from contextlib import contextmanager
import os
import signal
import subprocess


@contextmanager
def capture_focus_log(udid, destination):
    """Keep logs even when the journey raises; reap the stream before teardown."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = ['xcrun', 'simctl', 'spawn', udid, 'log', 'stream',
               '--style', 'compact', '--level', 'debug', '--timeout', '15m',
               '--predicate', 'process == "Neon" AND eventMessage BEGINSWITH "Neon focus"']
    # The native app bounds hit-test diagnostics; filtering excludes manuscript
    # contents and unrelated system logs. The OS timeout also bounds orphaned runs.
    with destination.open('w') as stream:
        stream.write('Neon focus diagnostics: simulator ' + udid + '\n')
        stream.flush()
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            yield
        finally:
            if process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=5)
            stream.write(f'\nFocus log stream exit: {process.returncode}\n')
