Within Google, the environment on GCP provided for playing with GCP is, by default, restricted using
GCP organization policies.  Some of these need to be relaxed for our testing.  In this directory
are policy files used by the `gcloud org-policies set-policy` command.  There is a file for
each of the policies we wish to modify.  Since the file needs to contain the name of the actual
GCP project to be modified, it is expected that pre-processing of the file will occur.

For example:

```
sed 's/PROJECTID/$(PROJECT)/g' policies/compute.requireOsLogin.yaml > policies/compute.requireOsLogin_final.yaml
gcloud org-policies set-policy policies/compute.requireOsLogin_final.yaml
```