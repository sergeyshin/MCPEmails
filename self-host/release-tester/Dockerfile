FROM postgres:18-alpine
RUN apk add --no-cache curl jq
COPY self-host/release-tester/test.sh /test.sh
RUN chmod 0555 /test.sh
CMD ["/test.sh"]
