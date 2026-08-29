# Exclusive lock guarding commands that write output/ and the task
# store: two nicolino processes running concurrently (e.g. a long-lived
# `auto` server and a one-off `build`) read and write the same state
# and corrupt each other's results. The lock is held for the whole
# process lifetime and released automatically on exit, so stale locks
# are impossible: a leftover .nicolino.lock is only ever a leftover
# file, never a stuck lock.
module BuildLock
  PATH = ".nicolino.lock"

  # Try to acquire the lock without blocking. Returns the open file
  # (keep it open for as long as the lock is needed) or nil when
  # another process holds it.
  def self.acquire : File?
    file = File.open(PATH, "w")
    # Non-blocking: fail fast with a clear message instead of hanging
    file.flock_exclusive(blocking: false)
    file.print(Process.pid.to_s)
    file
  rescue ex : IO::Error
    file.close if file
    Log.error { "Another nicolino process is already running in this directory (holding #{PATH}). Stop it before running this command." }
    nil
  end
end
