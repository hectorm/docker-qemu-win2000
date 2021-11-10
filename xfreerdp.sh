#!/bin/sh

set -eu
export LC_ALL=C

RDP_HOST=127.0.0.1
RDP_PORT=3389
RDP_USER=Administrator
RDP_PASSWORD=password

exec xfreerdp \
	/v:"${RDP_HOST:?}":"${RDP_PORT:?}" \
	/u:"${RDP_USER:?}" /p:"${RDP_PASSWORD:?}" \
	/log-level:INFO /cert:ignore \
	/gfx:RFX +gfx-progressive \
	+clipboard -compression -encryption
