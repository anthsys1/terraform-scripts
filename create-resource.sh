#!/bin/bash

# NOM;SUBNET;SERVICES;SECURITY_GROUP

generate_instance() {
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
        sed -i "s/{##SECURITY_GROUP##}/$column4/g" instance.tf
        sed -i "s/{##INSTANCE##}/$column1/g" instance.tf

        # Replace Subnet
        sed -i "s/{##SUBNET##}/$column2/g" instance.tf

        # Replace Service
        sed -i "s/{##SERVICE##}/$column3/g" instance.tf
    done < <(tail -n +2 $1)
    exit 0 
}

generate_network() {
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
        cat template/securitygroup.tf.template >> 10-network.tf

        # Remplate Terraform resource name & SG name
        sed -i "s/{##SECURITY_GROUP##}/$column1/g" securitygroup.tf
        sed -i "s/{##NAME##}/$column1/g" securitygroup.tf

        # Inject Ingress
        sed -i '/{##INGRESS##}/e tail template/ingress.template' securitygroup.tf

        # Replace all ingress values
        sed -i "s/{##PORT##}/$column2/g" securitygroup.tf
        sed -i "s/{##PROTOCOL##}/$column3/g" securitygroup.tf

        # Check if ingress need to use CIDR or SG and replace values
        if [[ "$column4" = *"CIDR"* ]]; then
            sed -i "s/{##CIDRORSG##}/$(echo 'cidr_blocks = ["{##CIDR##}"]')/g" securitygroup.tf
            sed -i "s|{##CIDR##}|$column5|g" securitygroup.tf
        else
            sed -i "s/{##CIDRORSG##}/$(echo 'security_groups = ["${aws_security_group.{##GROUP##}.id}"]')/g" securitygroup.tf
            sed -i "s/{##GROUP##}/$column5/g" securitygroup.tf
        fi


        # Check which port is used and change description
        if [ $column2 = "22" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow SSH/g" securitygroup.tf
        elif [ $column2 = "80" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow HTTP/g" securitygroup.tf
        elif [ $column2 = "3306" ]; then
            sed -i "s/{##DESCRIPTION##}/Allow DB/g" securitygroup.tf
        else
            sed -i "s/{##DESCRIPTION##}/Security Group/g" securitygroup.tf
        fi

        # Delete ingress marker
        sed -i '/{##INGRESS##}/d' securitygroup.tf


    done < <(tail -n +2 $1)
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