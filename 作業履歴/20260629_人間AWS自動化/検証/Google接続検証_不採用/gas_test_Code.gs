/**
 * 接続テスト用 GAS Web App
 * 目的: ローカルのPythonから「サーバー上のGAS」を起動できるか検証する。
 *       （本番のPhase1プロジェクトとは別に、テスト用プロジェクトへ貼って試すことを推奨）
 *
 * 使い方の概要:
 *   1) 新規スプレッドシート → 拡張機能 → Apps Script に本コードを貼る
 *   2) 下の SHARED_TOKEN を任意の合言葉に変更（Python側と一致させる）
 *   3) デプロイ → ウェブアプリ（実行=自分／アクセス=全員）→ /exec URL を控える
 *   4) gas_test_client.py から呼び出す
 */

var SHARED_TOKEN = 'change-me-合言葉';   // ★ Python側と同じ値にする

function doGet(e)  { return handle_(e, 'GET'); }
function doPost(e) { return handle_(e, 'POST'); }

function handle_(e, method) {
  var params = (e && e.parameter) || {};

  // POSTのJSONボディも解釈
  var body = {};
  if (e && e.postData && e.postData.contents) {
    try { body = JSON.parse(e.postData.contents); } catch (err) {}
  }

  // トークン検証（クエリ or ボディ）
  var token = params.token || body.token || '';
  if (token !== SHARED_TOKEN) {
    return json_({ ok: false, error: 'invalid token' });
  }

  var result = {
    ok: true,
    message: 'hello from GAS',
    method: method,
    serverTime: new Date().toISOString(),
    echo: (method === 'POST') ? body : params
  };

  // 任意: sheetId を渡すと、そのシート名とA1を読んで返す（シートアクセスも確認したい場合）
  var sheetId = params.sheetId || body.sheetId;
  if (sheetId) {
    try {
      var ss = SpreadsheetApp.openById(sheetId);
      var first = ss.getSheets()[0];
      result.spreadsheetName = ss.getName();
      result.firstSheetName = first.getName();
      result.a1 = first.getRange('A1').getValue();
    } catch (err) {
      result.sheetError = String(err);
    }
  }

  return json_(result);
}

function json_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
