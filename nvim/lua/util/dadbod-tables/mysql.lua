-- MySQL/MariaDB table helpers for dadbod-ui
-- On Devuan, mysql is provided by mariadb-client (wire-compatible)
-- ROW_COUNT() for modifying queries is handled in util/dadbod-helpers.lua
return {
  List = "SELECT * FROM `{table}` LIMIT 200",
  Count = "SELECT COUNT(*) FROM `{table}`",
}
