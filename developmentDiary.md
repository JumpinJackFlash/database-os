# A diary of development activities... #

## December 17th, 2024 ##
### Recap of development... ###
1. After a few days of work to setup the new AsterionDB/DbTwig data-layer micro-service architecture, I'm back at work on this project. We're now able to make complete data-layer calls in between services in DbTwig w/ proper parameter signatures etc. etc.
2. Added buttons to start and stop the VM's.
3. Got the start/stop logic in the vm_manager package working (again).
4. Started and stopped my first VM from the web interface..!!!

### Music on the playlist...  ###
1. Grateful Dead - Live Dead
2. Jackson Browne - Running on Empty

## December 14th, 2024 ##
### Recap of development... ###
1. Had a big debate today with myself on whether to use JWT or not. Not...!!! We enforce session checking on every call to the DB. I left in the hooks for JWT Secret/Signing Key and JWT Expires In for optimistic middle-tier session checking if it's ever needed.
2. Sorted out login/logout cycle.
3. Added a table to the virtualMachines page to display data from getListOfVirtualMachines.

### Music on the playlist...  ###
1. Neil Young - Neil Young
2. David Bowie - Live at the SMO Civic '72
3. Steely Dan - Pretzel Logic
4. The Kinks - Sleepwalker

## December 13th, 2024 ##
### Recap of development... ###
1. Start coding up a login page in the vm-manager web-app.
2. Created middleware.ts to handle re-directs
3. Created serverActions.getLoginPageSettings
4. Started to integrate NextUI into the design
5. Use NextUI Pro's Login page.
6. Created serverActions.createUserSession and serverActions.terminateUserSession
7. Created VirtualMachines page
8. Worked out session creation and termination.

### Music on the playlist...  ###
1. Mozart - A Little Night Muzik...
2. Faces - A Nod Is As Good As A Wink
3. Led Zeppelin IV
4. U2 - The Joshua Tree

## December 12th, 2024 ##
### Recap of development... ###
1. Got a bright idea, keep a daily log!!!  
1. Created function vm_manager.get_list_of_virtual_machines.  
1. Created middle_tier_map in the asteriondb_dbos schema.  
1. Created an entry in middle_tier_map for vm_manager.get_list_of_virtual_machines.  
1. Setup grants and synonyms for asteriondb_dbos to dbtwig.  
1. Setup grants for dbtwig to asteriondb_dbos.  
1. Enrolled dbos as a service in dbtwig.  
1. Setup call to dbTwig in vm-manager web-app.
2. Created get_list_of_virtual_machines function in vm_manager package.
3. Mapped a call to get_list_of_virtual_machines out through dbTwig.
4. Created getListOfVirtualMachines function in vm_manager web-app. It works!!!

### Music on the playlist... I mainly listen to Jazz & Classical Music, Hank & Classic Rock ###
1. King Sunny Ade - Ade Special  
1. Mott The Hoople - Mott
1. Lou Reed - Rock N Roll Animal
