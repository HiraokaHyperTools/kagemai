## 特定のフィールドの値を勝手に変更するサンプル

## 状態フィールドの半自動設定。

=begin

@project.add_add_message_hook {|report, message|
  if message['assigned'] != '未定' && message['status'] == '新規' then
    message['status'] = '割当済み'
  end

  if message['resolution'] != '未処理' && message['status'] != '完了' then
    message['status'] = '確認待ち'
  end
}

=end
