DOKKU_HOST:=breton.ch
DOKKU_LETSENCRYPT_EMAIL:=manu@ibimus.com
DOKKU_MARIADB_SERVICE:=mysql

LOCAL_BACKUP_PATH:=~/var/dokku_backup

###
# ONE OFF

init-host:	
	# set email to use for let's encrypt globally
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
	ssh -t dokku@${DOKKU_HOST} config:set --global DOKKU_LETSENCRYPT_EMAIL=${DOKKU_LETSENCRYPT_EMAIL}
	# setup MariaDB
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-mariadb.git
	ssh -t dokku@${DOKKU_HOST} mariadb:create ${DOKKU_MARIADB_SERVICE} || true
	# pull initial docker image for Wordpress
	ssh -t ${DOKKU_HOST} docker pull wordpress:4.9-php5.6-apache
	# and tag it on host to make it available to dokku
	ssh -t ${DOKKU_HOST} docker tag wordpress:4.9-php5.6-apache dokku/wordpress:4.9-fpm-alpine


###
# CREATE & DESTROY

create: validate-app
	# create an app and set environment variable+port before 1st deployment
	ssh -t dokku@${DOKKU_HOST} apps:create ${NAME}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} SITE_URL=${SITE_URL}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} SITE_TITLE=\"${SITE_TITLE}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_USER=\"${WP_USER}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_PASSWORD=\"${WP_PASSWORD}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_EMAIL=${WP_EMAIL}
	# link with DB
	ssh -t dokku@${DOKKU_HOST} mariadb:link ${DOKKU_MARIADB_SERVICE} ${NAME}
	# add remote and push app to trigger deployment on host
	git remote add ${NAME} dokku@${DOKKU_HOST}:${NAME}
	git push ${NAME} master
	# switch to HTTPs
	ssh -t dokku@${DOKKU_HOST} letsencrypt ${NAME}

destroy: validate-app
	ssh -t dokku@${DOKKU_HOST} apps:destroy ${NAME}
	git remote remove ${NAME}


###
# MONITORING

apps:
	ssh -t dokku@${DOKKU_HOST} apps:report ${NAME}

domains:
	ssh -t dokku@${DOKKU_HOST} domains:report ${NAME}

proxy:
	ssh -t dokku@${DOKKU_HOST} proxy:report ${NAME}

storage:
	ssh -t dokku@${DOKKU_HOST} storage:report ${NAME}


###
# BACKUP & RESTORE

backup-all:
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/ ${LOCAL_BACKUP_PATH}

backup: validate-app
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/${NAME} ${LOCAL_BACKUP_PATH}/

restore: validate-app
	rsync -av ${LOCAL_BACKUP_PATH}/${NAME} ${DOKKU_HOST}:/var/lib/dokku/data/storage/


###
# INPUT VALIDATION

validate-app:
ifndef NAME
	$(error NAME is not set)
endif
