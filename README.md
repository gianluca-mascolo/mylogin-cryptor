# mylogin-cryptor
Encode/Decode mylogin.cnf with bash

## Example

### Decrypt
```
]$ ./mylogin_decoder.sh -f mylogin_example.cnf
[example]
user = "foobar"
password = "example_pwd"
host = "mysqlhost"
port = 3306
```
### Encrypt

```
]$ ./mylogin_encoder.sh -f /tmp/mylogin_encrypted.cnf -p ./mylogin_plaintext.ini
```
