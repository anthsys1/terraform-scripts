#!/bin/bash

# NOM;SUBNET;SERVICES;SECURITY_GROUP

generate_instance() {

    # Terraform don't like '-' and capital letter in resource name...
    sed -i "s|-|_|g" instances_matrix.csv
    sed -i 's/.*/\L&/g' instances_matrix.csv

    while IFS=";" read -r column1 column2 column3 column4
    do

        echo "Creating Instance.."
        echo
        echo "NOM: $column1"
        echo "SUBNET: $column2"
        echo "SERVICES: $column3"
        echo "SECURITY_GROUP: $column4"
        echo ""

        # Create Instance file
        cat template/instance.tf.template >> 20-instance.tf

        # Remplate Terraform resource name & Instance name
        sed -i "s/{##SECURITY_GROUP##}/$column4/g" 20-instance.tf
        sed -i "s/{##INSTANCE##}/$column1/g" 20-instance.tf

        # Replace Subnet
        sed -i "s/{##SUBNET##}/$column2/g" 20-instance.tf

        # Replace Service
        sed -i "s/{##SERVICE##}/$column3/g" 20-instance.tf
    done < <(tail -n +2 $1)
    exit 0 
}

generate_network() {

    # Terraform don't like '-' and capital letter in resource name...
    sed -i "s|-|_|g" flow_matrix.csv
    sed -i 's/.*/\L&/g' flow_matrix.csv

    while IFS=";" read -r column1 column2 column3 column4 column5
    do

        echo "Creating Security Group.."
        echo
        echo "SECURITY_GROUP: $column1"
        echo "PORT: $column2"
        echo "PROTOCOL: $column3"
        echo "TYPE: $column4"
        echo "SOURCE: $column5"
        echo ""

        # Create SG file
        if [ -f "10-securitygroup.tf" ]; then
            if ! cat "10-securitygroup.tf" | grep -q "$column1" ; then
                cat template/securitygroup.tf.template >> 10-securitygroup.tf
            fi
        else
            cat template/securitygroup.tf.template >> 10-securitygroup.tf
        fi

        # Remplate Terraform resource name & SG name
        sed -i "s|{##SECURITY_GROUP##}|$column1|g" 10-securitygroup.tf

        # Ingress
        echo "TEST"
        sed -i "s|{SGREPLACE}|$column1|g" 10-securitygroup.tf
        cat template/ingress.template >> ${column1}.ingress


        # Replace all ingress values
        sed -i "s/{##PORT##}/$column2/g" ${column1}.ingress
        sed -i "s/{##PROTOCOL##}/$column3/g" ${column1}.ingress

        # Check if ingress need to use CIDR or SG and replace values
        if [[ "$column4" = *"CIDR"* ]]; then
            sed -i "s/{##CIDRORSG##}/$(echo 'cidr_blocks = ["{##CIDR##}"]')/g" ${column1}.ingress
            sed -i "s|{##CIDR##}|$column5|g" ${column1}.ingress
        else
            sed -i "s/{##CIDRORSG##}/$(echo 'security_groups = ["aws_security_group.{##GROUP##}.id"]')/g" ${column1}.ingress
            sed -i "s/{##GROUP##}/$column5/g" ${column1}.ingress
        fi


        # Check which port is used and change description
        if [ $column2 = "22" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow SSH/g" ${column1}.ingress
        elif [ $column2 = "80" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow HTTP/g" ${column1}.ingress
        elif [ $column2 = "3306" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow DB/g" ${column1}.ingress
        else
            sed -i "s/{##DESCRIPTION##}/Security Group/g" ${column1}.ingress
        fi
    done < <(tail -n +2 $1)

    for SGROUP in $(ls *.ingress)
    do
        echo "SGROUP: " $SGROUP

        GROUP_NAME=$(echo $SGROUP | cut -d"." -f1)
        echo "GROUP NAME: " $GROUP_NAME

        sed -i "/{##INGRESS-$GROUP_NAME##}/e cat $SGROUP" 10-securitygroup.tf
        sed -i "/{##INGRESS-$GROUP_NAME##}/d" 10-securitygroup.tf
        rm $SGROUP
    done

    exit 0
}

if [[ "$1" = *"flow"* ]]; then
    echo "[*] Generating Network files"
    generate_network $1
elif [[ "$1" = *"instance"* ]]; then
    echo "[*] Generating Instance files"
    generate_instance $1
else
    echo "[*] Not a proper file, exiting"
    exit 1
fi