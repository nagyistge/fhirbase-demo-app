# Fhirbase demo

## Build into the fhirbase.github.io

Assume, that you have [fhirbase.github.io](https://github.com/fhirbase/fhirbase.github.io)
cloned locally and located on the same level, as fhirbase-demo-app repo

```sh
env PORT=11111 BASEURL='http://pg2web.coreos.health-samurai.io:10001/' npm run-script build
rm -rf ../fhirbase.github.io/demo/ && cp -R ./dist ../fhirbase.github.io/demo
cd ../fhirbase.github.io && commit -am "Demo and Tutorial update" && git push && cd ../fhirbase-demo-app
```

## Run with CoreOS pg2web target

```sh
env PORT=11111 BASEURL='http://pg2web.coreos.health-samurai.io:10001/' npm run
```

## Run with CoreOS pg2web target

Assume, that you have pg2web and fhirbase docker containers runnin locally.

```sh
env PORT=11111 BASEURL='http://192.168.59.103:8888/' npm start
```
