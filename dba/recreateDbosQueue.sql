set echo on
connect &1
@dropDbosQueue &2
@createDbosQueue &2
exit
