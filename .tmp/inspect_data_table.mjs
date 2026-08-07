import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "C:/GameDev/GameProject/project-nhn/.tmp/data_table_latest_20260805.xlsx";
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const overview = await workbook.inspect({
  kind: "workbook,sheet",
  include: "id,name",
  maxChars: 12000,
});
console.log("OVERVIEW");
console.log(overview.ndjson);

const tables = await workbook.inspect({
  kind: "table",
  maxChars: 60000,
  tableMaxRows: 300,
  tableMaxCols: 60,
  tableMaxCellChars: 300,
});
console.log("TABLES");
console.log(tables.ndjson);
