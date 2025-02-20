#!/bin/bash

helm install traefik traefik/traefik --namespace traefik --create-namespace --values ./helm/values.yml
