# R2 bucket is managed in terraform/shared/ (independent state).
# openclaw.json is injected via Secret Manager, not stored in R2.
# R2 is used exclusively for persistent memory (workspace files, sessions).
