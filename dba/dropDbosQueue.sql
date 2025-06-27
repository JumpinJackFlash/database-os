begin

    dbms_aqadm.stop_queue('&1..dbos$vm_monitor_q');
    dbms_aqadm.drop_queue(queue_name => '&1..dbos$vm_monitor_q');
    dbms_aqadm.drop_queue_table(queue_table => '&1..dbos$vm_monitor_qt');

end;
.
/
