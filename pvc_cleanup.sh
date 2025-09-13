#!/bin/bash 

#login to cluster
#once logged in enter the pvcname and namespace
read -p "enter the pvc name: " pvc_name
read -p "enter namespace: " namespace

#check if pvc name and namespace is given correctly
if [ -z "$pvc_name" ]; then 
    echo "pvc doesnt exist" 
    exit 
fi 

if [ -z "$namespace" ]; then 
    echo "namespace doesnt exist" 
    exit 
fi

#fetch the pod name 
pod_name="$(kubectl describe pvc -n "$namespace" | grep -i used | awk '{print $3}')"

#exec into the pod 
kubectl exec -it "$pod_name" -n "$namespace" /bin/sh 

#find the max filled mounted_vol . for this run df -k , sort it by memory usage and fetch the first file 
mounted_dir="$(df -k --output=source,size,used,pcent,target | tail -n +2 | sort -k3 -nr | head -1)"

#if mounted_dir is a directory then find the highest space consuming file which were modified last 45 days ago
if [ -d "$mounted_dir" ]; then 
    target_file="$(find "$mounted_dir" -type f -mtime +45 -exec du -k {} + | sort -nr | head -5)"
    
    #echo all the files found and store first coloumn (filename) in file variable 
    echo "$target_file" | while read -r file; do 
        read -p "do u want to delete the file: " APPROVAL 
        read -p "delete or archive the file: " ACTION

        if [ "$APPROVAL" == "YES" ] && [ "$ACTION" == "DELETE" ]; then 
            rm -rf "$file"
            echo "$file file deleted"
        else 
            if [ "$APPROVAL" == "YES" ] && [ "$ACTION" == "ARCHIVE" ]; then
                tar -czvf "$file-$(date +%F).tar.gz" "$file"
                echo "$file archived"
            else
                echo "dont do anything" 
            fi
        fi
    done
fi
