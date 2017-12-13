# shyaml - A shell yaml parser script

This is a yaml parser for bash script to use simply, like pyyaml lib. 

This script is being perfect. I'd be happy to listen your suggestion, and you can write them as issues.


## Shyl object

For temporary store yaml key-value pairs, there defined a data structure (named Shyl).

Shyl object array is created when loaded a yaml file.

Shyl object array will be used when do query task or update value task to a yaml file.

Single shyl object's struct is: `key1.key2.key3[n].key4:value`


## What shyaml can do

This shell script can do more than parsing a yaml file.

* Load a yaml file and then output a shyl object array  

* Query some the key's value from a shyl object stream

* Query some the key's value from a yaml file

* Update some the key's value from a shyl object stream

* Convert a shyl object array stream to a yaml file


## How to use

Give the shyaml script(./shyaml.sh) execution permission before please.

When execute command `./shyaml.sh --help`, we would get follow messages:

```
Usage: ./shyaml.sh [option...]

 -f/load/loadYaml2Shyl <file>               Load a yaml to Shyl object(A shyaml's special data struct)
                                              e.g.: ./shyaml.sh -f service.yaml
 -g/getValue/getShylValue <key>             Query a key(multi keys must combined with '.')'s value from a Shyl object
                                            !!You must load a yaml file firstly
                                              e.g.1: ./shyaml.sh -f service.yaml -g key1.key2
                                              e.g.2: ./shyaml.sh -f service.yaml |  -g key1.key2
 -gy/getYamlValue/getValueByYaml <key>      Query a key(multi keys must combined with '.')'s value from just from a yaml file
                                              e.g.: ./shyaml.sh -gy key1.key2 service.yaml
 -s/setValue/setShylValue <key> <value>     Set a key(multi keys must combined with '.')'s value from a Shyl object
                                            !!You must load a yaml file firstly
                                              e.g.1: ./shyaml.sh -f service.yaml -s key1.key2 new_value
                                              e.g.2: ./shyaml.sh -f service.yaml |  -s key1.key2 new_value
 -c/save/saveShyl2Yaml <file>               Create a yaml file by a Shyl object
                                            !!You must load a yaml file firstly
                                              e.g.1: ./shyaml.sh -f service.yaml -c s.yaml
                                              e.g.2: ./shyaml.sh -f service.yaml |  -c s.yaml
 -h/--help                                  Display  usage
```

So, you can use a single command with '-f' and '-g[y]|-s|-c' to finish complex mission.

## Ues range

So far, shyaml can handle follow yaml content types:

* Simple key value pair, e.g. 
```yaml
a: 1
b: 2
```
* Array value, e.g. 
```yaml
a:
- b: 1
  c:
    d: 2
- b: 3
  c:
    d: 4
```
* Value contains {}, e.g.
```yaml
a: 1
b: {x: "",y: 123}
```