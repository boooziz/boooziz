#!/bin/bash
    echo -e "\n=========================================="
    echo -e "\e[0;32mStep 3\e[m: Remove default VPC in all regions $(date)...\n"

    # For all regions, find default vpc and removing it with its internet gateway and subnets
    for reg in $(aws ec2 describe-regions --region-names --query "Regions[][RegionName]" --output text)
    do
	printf "  - In region %14s: " "${reg}"
	defaultvpc=$(aws ec2 describe-vpcs \
                        --filter Name=isDefault,Values=true --query "Vpcs[][VpcId]" --output text --region "${reg}")
	ExitIfERR $? "\n*** ERROR *** Can't find default vpc in region ${reg} (describe-vpcs)"

	if [ "${defaultvpc}" != "" ]; then
	    echo -e "deleting \e[0;32m${defaultvpc}\e[m...\c"

	    # Delete Internet gateway
	    igw=$(aws ec2 describe-internet-gateways \
	              --filter "Name=attachment.vpc-id,Values=${defaultvpc}" \
                      --query "InternetGateways[0].InternetGatewayId" --output text --region "${reg}")
	    ExitIfERR $? "\n*** ERROR *** Can't find Internet Gateway for VPC ${defaultvpc}"
	    if [ "${igw}" != "" ] && [ "${igw}" != "None" ]; then
		echo -e ".\c"
		aws ec2 detach-internet-gateway --internet-gateway-id "${igw}" --vpc-id "${defaultvpc}" --region "${reg}"
		ExitIfERR $? "*** ERROR *** Can't detach internet gateway ${igw} in region ${reg}"
		echo -e ".\c"
		aws ec2 delete-internet-gateway --internet-gateway-id "${igw}" --region "${reg}"
		ExitIfERR $? "*** ERROR *** Can't delete internet gateway ${igw} in region ${reg}"
	    fi

	    # Delete Subnets
	    subnets=$(aws ec2 describe-subnets \
	                  --filters "Name=vpc-id,Values=${defaultvpc}" \
                          --query "Subnets[].SubnetId" --output text --region "${reg}")
	    if [ "${subnets}" != "" ]; then
		for subnet in ${subnets}
		do
		    echo -e ".\c"
		    aws ec2 delete-subnet --subnet-id "${subnet}" --region "${reg}"
		    ExitIfERR $? "*** ERROR *** Can't delete subnet ${subnet} in region ${reg}"
		done
	    fi

	    # Delete VPC
	    echo -e ".\c"
	    aws ec2 delete-vpc --vpc-id "${defaultvpc}" --region "${reg}"
	    ExitIfERR $? "*** ERROR *** Can't delete vpc ${defaultvpc} in region ${reg}"

	    echo -e "Done"
	else
	    echo -e "no default vpc found"
	fi

    done

    echo -e "\nDone"
