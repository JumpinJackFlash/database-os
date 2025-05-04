begin

  dbms_aqadm.create_queue_table(
    queue_table => '&1..dbos$vm_manager_qt',
    queue_payload_type => '&1..dbos$message_t');

  dbms_aqadm.create_queue(
    queue_name => '&1..dbos$vm_manager_q',
    queue_table => '&1..dbos$vm_manager_qt');

  dbms_aqadm.start_queue('&1..dbos$vm_manager_q');

end;
.
/  


