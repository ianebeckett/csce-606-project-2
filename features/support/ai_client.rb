# Scenarios plug in their own fake AI client; reset it so none leaks into the next.
After { use_ai_client(nil) }
