version 2- local state and ssh-based

only four nodes: arch debian ubuntu and al2023. specifying the private key file as a locally generated private key file. disabling strict host checking

template file created that creates inventory ini and user-data.sh dynamically at script runtime, but of course doesnt work quite as well if you need to replace any ec2 instances using terraform

There is a public ip for the ansible control node- of course ssh has to be enabled here. user-data.sh script is very plain with HEREDOC for inventory.ini, anisble lab key pem, ansible.cfg etc. basic commands to change ownership of files to allow for use etc
i never really got arch to work so it just sits in there and doesnt work effectively too much crap and race conditions and i got tired fairly easy from what i can recall- idk its not there so who cares and honestly arch isnt something you'd ever even use in this environment
v2
bootstrap. moving from local to cloud managed and at some point had to change from dynamodb to a specific s3 bucket only option
Still locally generated inventory, ansible cfg, etc


we move to using ansible over ssm instead of ssh, technically frees us up for byte limits which is kinda cool. also enables us to turn off a public ip for the ansible control node, and we can simply ssm into anything. one thing i had to do was create new profiles or policies that allowed several bucket allows, as well as some denys. effectivelty needed to ensure that information could be written for the data in transit (its different from the ssh based flow )



we also move to using al2023, debiann, ubuntu, rhel, opensuse, etc and making everything work from home. also had issues where i needed to use bracketed paste mode for rhel derived nodes in etc/inputrc

as i encountered depency and distro-specific issues i needed to gradually add more commands. you could argue that the excisting user-data scripts for some of these managed nodes are brittle. but who cares you can just tear them down again and again



oh god there was the ridiculius zipper thing for package refreshes. where i couldnt install python3 because zipper hadnt finished its initizlization or whatever so we add a simple until loop for this



We remove outside traffic and only allow internal traffic from control node essentially and only ssm etc



oin control node script (well with scripts in general i added claude's suggested set euo pipefail which can feel contentious for error handling. simple exec to capture logs if needed and write stderr to stdout. curl for session manager plugin and install it, then cretae dedicated ansible dir, then clone my existing directory here and grab playbooks and roles  so i dont need to pull them back on my end. still using statici nventory and ansible fg trghough.



then suddenly to dynamic inventory. we add an aws_ec2.yml plugin and dont modify a whoel lot else hongestly, then i start spending even more time doing the two dedicated lab components with a universal baseline and then an os-hardening playbook most of it happening there. then we run into the girthub flow specific errors i had for ansible and terraform linting

oh man oh fun it was i guess
