## ����Υե�����ɤ��ͤ򾡼���ѹ����륵��ץ�

## ���֥ե�����ɤ�Ⱦ��ư���ꡣ

=begin

@project.add_add_message_hook {|report, message|
  if message['assigned'] != '̤��' && message['status'] == '����' then
    message['status'] = '�����Ѥ�'
  end

  if message['resolution'] != '̤����' && message['status'] != '��λ' then
    message['status'] = '��ǧ�Ԥ�'
  end
}

=end
