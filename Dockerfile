FROM elasticsearch:1.5.0
ADD elasticsearch-srv-discovery-1.5.1.zip /
RUN plugin install srv-discovery --url file:///elasticsearch-srv-discovery-1.5.1.zip
