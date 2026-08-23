# Sanitized fixtures

Only synthetic or irreversibly sanitized payment examples belong here. Never commit real notifications, SMS content, account numbers, names, or transaction identifiers.

- `candidate_expense.json`: schema-v1 synthetic WeChat purchase candidate with direction and transaction-kind evidence, HMAC source identity, offset-only references, and no raw notification text.
