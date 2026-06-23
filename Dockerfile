FROM nginx:1.19-alpine

RUN addgroup -g 10001 appuser && \
    adduser -u 10001 -G appuser -h /home/appuser -D appuser

COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/

RUN chown -R appuser:appuser /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chown -R appuser:appuser /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appuser /var/run/nginx.pid

USER appuser

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
