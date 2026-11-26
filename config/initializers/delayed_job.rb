Delayed::Worker.max_run_time = 1.minute
# Delayed Job polls globally; the single judge queue worker uses a short delay
# so an already-ready judge is not left waiting for the next polling cycle.
Delayed::Worker.sleep_delay = 1
