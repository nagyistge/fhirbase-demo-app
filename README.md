fhirplace example plugin
======================

```sh
 # install nvm
 nvm use 0.10

 npm install
 npm start # to start dev server on localhost:8080
 npm run-script build # to build into dist directory

 `npm bin`/fhirbase # to publish
```
### Run with OAuth2

Asume [lab-wall][] running on `http://localhost:3000` and
application it self running on `http://localhost:8080`.

```sh
nvm use 0 \
  && env \
     PORT=8080 \
     BASEURL='http://localhost:3000/fhir' \
     OAUTH_CLIENT_ID='your-oauth-client-id' \
     OAUTH_CLIENT_SECRET='your-oauth-client-secret' \
     OAUTH_REDIRECT_URI='http://localhost:8080/#/redirect' \
     OAUTH_SCOPE='all' \
     OAUTH_RESPONSE_TYPE='token' \
     OAUTH_AUTHORIZE_URI='http://localhost:3000/oauth/authorize' \
     npm start
```