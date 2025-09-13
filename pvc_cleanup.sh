#!/bin/bash 

#author=navneet bhardwaj

#login to cluster desired using kubectl
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

#fetch the pod name from namespace and pvc provided  
pod_name="$(kubectl describe pvc "$pvc_name" -n "$namespace" | grep -i used | awk '{print $3}')"

# NOTE: only change below → run commands *inside* the pod (no interactive shell)
if [ -n "$pod_name" ]; then 
    echo "inside pod"

    # find the max filled mounted_vol (run df inside the pod)
    mounted_dir="$(
      kubectl exec -n "$namespace" "$pod_name" -- sh -lc \
      'df -k --output=source,size,used,pcent,target | tail -n +2 | sort -k3 -nr | head -1'
    )"

    # if mounted_dir is a directory then find highest space-consuming files (>45 days) inside the pod
    if [ -d "$mounted_dir" ]; then 
        target_file="$(
          kubectl exec -n "$namespace" "$pod_name" -- sh -lc \
          'find "'"$mounted_dir"'" -type f -mtime +45 -exec du -k {} + | sort -nr | head -5'
        )"
        
        # echo all the files found and process each; actions executed inside the pod
        echo "$target_file" | while read -r file; do 
            read -p "do u want to delete the file: " APPROVAL 
            read -p "delete or archive the file: " ACTION
##
            if [ "$APPROVAL" == "YES" ] && [ "$ACTION" == "DELETE" ]; then

                kubectl exec -n "$namespace" "$pod_name" -- rm -rf "$file"
                echo "$file file deleted"
            else 
                if [ "$APPROVAL" == "YES" ] && [ "$ACTION" == "ARCHIVE" ]; then
                    kubectl exec -n "$namespace" "$pod_name" -- sh -lc 'tar -czvf "$1-$(date +%F).tar.gz" "$1"' _ "$file"
                    echo "$file archived"
                else
                    echo "dont do anything" 
                fi
            fi
        done
    fi
fi
