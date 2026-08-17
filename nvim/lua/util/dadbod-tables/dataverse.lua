-- Dataverse table helpers for dadbod-ui (used with custom dvquery adapter)
return {
  List = "SELECT TOP 200 * FROM {table}",
  Columns = ".columns {table}",
  Count = "SELECT COUNT(*) FROM {table}",
}
