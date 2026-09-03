## Introduction

VCEditor is for building models of the physical collation of manuscripts, and then visualizing them in various ways. The VCEditor project is led by Dot Porter at the [Schoenberg Institute for Manuscript Studies](https://schoenberginstitute.org/) at the University of Pennsylvania and Alberto Campagnolo. VCEditor is built on code developed by the [University of Toronto Libraries](https://onesearch.library.utoronto.ca/about) and the [Old Books New Science lab](https://oldbooksnewscience.com/), under the direction of Alexandra Gillespie.

## Development setup with Docker

The VCEditor development environment runs on machine-local docker.

### Docker environment

### Bring up the docker env


```
docker-compose -f docker-compose-dev.yml up  
```

Note: Do not use the `-d` flag. You'll need information from the log output to create the user account needed to work with VCEditor (instructions below). 

The application is accessible at http://localhost:3000

### Create a user account

When a user creates an account, an email is sent to a VCEditor team member who is given a link to confirm the account. In development, the content of the email with the link is printed to the app service log.

To create and approve a development user:

- Go to the home page <http://localhost:3000>
- Click "Create account"
- Enter a name, email and password. It does not have to be a real email address; e.g., `test@test.com` is fine.
- From the docker log copy the link from the confirmation email body It will look like this: 
  - https://localhost:3000/confirmation?confirmation_token=GeZfMcfUaZtwoNMeRtNQvvqU
- Paste the link into a browser, change the protcol to `http`:
  - http://localhost:3000/confirmation?confirmation_token=GeZfMcfUaZtwoNMeRtNQvvqU
- Hit enter and the account will be approved

#### Testing

Testing is run in the docker containers.

To run the Rails tests, do:

```
docker exec -it $(docker ps -q -f name="viscoll_api") bash
RAILS_ENV=test bundle exec rspec 
```

To run the Javascript tests, do:

```
docker exec -it $(docker ps -q -f name="viscoll_app") bash
npm test
```

### Development docker stack

Five docker services run in the development environment:

- `app` -- the React/Redux frontend
- `api` -- the Rails backend
- `xproc` -- the XSLT pipeline service
- `mongo` -- MongoDB instance
- `mongo-express` -- Mongo admin interface

The `api` and `xproc` service images are built during docker compose startup. 

## Deploying in Portainer

Staging and production deployments are run as docker stacks in Portainer. Both are on the same host. There are addresses are:

- Staging: https://vceditor.library.upenn.edu:8443
- Production: https://vceditor.library.upenn.edu

#### Required environment variables

These variables are set in each stack's environment variable section:

```dotenv
MAILER_HOST=an.smtp.host
MAILER_DEFAULT_FROM=<siteadmin>@upenn.edu
MAILER_DOMAIN=vceditor.library.upenn.edu
MAILER_PORT=25
APPLICATION_HOST=vceditor.library.upenn.edu:443 # or vceditor.library.upenn.edu:8443 
# ADMIN_EMAIL: addresses of confirmation email recipients
ADMIN_EMAIL=address1@upenn.edu,address2@upenn.edu,adress3@gmail.com
SECRET_KEY_BASE=railssecretkey
RAILS_ENV=production
RAILS_SERVE_STATIC_ FILES=true
XPROC_URL=http://xproc:2000
# `PROJECT_URL` -- the application host; used by Traefik
PROJECT_URL=vceditor.library.upenn.edu
RELEASE_TAG=animagetag
INSTANCE=production # or staging
HONEYBADGER_API_KEY=anapikey
```

#### Prduction docker images

The GitLab pipeline builds the production API and XProc images. 

The pipeline push the images in GitLab container registry, but does not deploy the application. The Portainer Stacks feature is used to pull images and deploy the application. 

## Copyright and License

Copyright 2020 University of Toronto Libraries

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
