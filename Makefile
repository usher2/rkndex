.PHONY : \
    build-dexer \
    build-gitar \
    build-giweb \
    build-pg \
    build-rslv \
    build-u2ex \
    push-dexer \
    push-gitar \
    push-giweb \
    push-pg \
    push-rslv \
    push-u2ex \
    run-dexer \
    run-gitar \
    run-giweb \
    run-pg \
    run-psql \
    run-psql-local \
    run-rslv \
    all

all :
	: wut wut

RKN_GIT := $$PWD/rkn.git
RSLV_SRV := $$PWD/rvzdata

-include local.mk

# `tar` is used to avoid adding huge $PWD to context
build-dexer :
	tar cz Dockerfile.rkndexer rkndex rkndexer | docker build -t darkk/rkn:dexer -f Dockerfile.rkndexer -
build-gitar :
	tar cz Dockerfile.rkngitar certenroll.ca.rt.ru ssh_config rkndex rkngitar | docker build -t darkk/rkn:gitar -f Dockerfile.rkngitar -
build-giweb :
	tar cz Dockerfile.rkngiweb rkndex | docker build -t darkk/rkn:giweb -f Dockerfile.rkngiweb -
build-pg :
	tar cz Dockerfile.rknpg ndx.sql pg-distrust.sh | docker build -t darkk/rkn:pg -f Dockerfile.rknpg -
build-rslv :
	tar cz Dockerfile.rknrslv ssh_config.resolv resolv-ar | docker build -t darkk/rkn-rslv -f Dockerfile.rknrslv -
build-u2ex :
	tar cz Dockerfile.rknu2ex rkndex usher2_exporter | docker build -t darkk/rkn-u2ex -f Dockerfile.rknu2ex -

push-dexer :
	docker push darkk/rkn:dexer
push-gitar :
	docker push darkk/rkn:gitar
push-giweb :
	docker push darkk/rkn:giweb
push-pg :
	docker push darkk/rkn:pg
push-rslv :
	docker push darkk/rkn-rslv
push-u2ex :
	docker push darkk/rkn-u2ex

run-dexer :
	docker run --rm -ti --net=host \
	    -v $$PWD:/mnt:ro \
	    -e PGHOSTADDR=127.0.0.1  \
	    -e PGUSER=$(POSTGRES_USER) \
	    -e PGDATABASE=$(POSTGRES_DB) \
	    -e PGPASSWORD=$(POSTGRES_PASSWORD) \
	    -e GIWEB=http://127.0.0.1:12283 \
	    --workdir /mnt \
	    --entrypoint /bin/bash \
	    darkk/rkn:dexer
run-gitar :
	docker run --rm -ti --net=host \
	    -v $(RKN_GIT):/srv/rkn.git \
	    darkk/rkn:gitar \
	    --git-dir /srv/rkn.git \
	    --eais-fqdn example.org --eais-token /dev/null \
	    --capath /nonexistent \
	    --prom-port 9317
run-giweb :
	docker run --rm -ti --net=host \
	    -e RKNDEX_GIWEB_GITAR_DIR=/srv/rkn.git \
	    -e RKNDEX_GIWEB_SETTINGS=/dev/null \
	    -v $(RKN_GIT):/srv/rkn.git:ro \
	    darkk/rkn:giweb \
	    gunicorn --bind 127.0.0.1:12283 rkndex.giweb:app
run-pg :
	docker run --rm -ti --net=host --name=rknpg \
	    -e POSTGRES_USER=$(POSTGRES_USER) \
	    -e POSTGRES_DB=$(POSTGRES_DB) \
	    -e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
	    darkk/rkn:pg
run-psql :
	docker exec -ti rknpg psql 'postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@127.0.0.1/$(POSTGRES_DB)'
run-psql-local :
	psql 'postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@127.0.0.1/$(POSTGRES_DB)'
run-rslv :
	docker run --rm -ti --net=host \
		-v $(RSLV_SRV):/srv \
		darkk/rkn-rslv \
		--git-dir /srv/git \
		--objects-xmx 2g \
		--window-memory 1g \
		--src /srv/spool \
		--dst-done /srv/done \
		--prom-port 12020
