FROM elasticsearch:1.7.3
ADD elasticsearch-srv-discovery.zip /
RUN plugin install srv-discovery --url file:///elasticsearch-srv-discovery.zip
