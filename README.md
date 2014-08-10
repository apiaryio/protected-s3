# protected-s3

Simple application that allows you to display the content of your S3 to authorised users only.

## Instalation 

* npm start

Don't forget to set environment variables:

* `NODE_ENV' to `production` (or your bucket will be open)
* `ALLOWED_DOMAINS` to comma-separated list of domains you are accepting auth from
