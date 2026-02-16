# Dockerfile - Recipe to build our application image

# Stage 1: Use nginx as our web server
# nginx:alpine is a lightweight version (~23MB vs ~140MB)
FROM nginx:1.25-alpine

# Add labels for documentation
LABEL maintainer="your-email@example.com"
LABEL description="EKS Learning Project - Sample Web App"
LABEL version="1.0"

# Remove default nginx welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy our app files to nginx's serve directory
COPY index.html /usr/share/nginx/html/
COPY favicon.ico /usr/share/nginx/html/
COPY js/ /usr/share/nginx/html/js/
COPY style/ /usr/share/nginx/html/style/
COPY meta/ /usr/share/nginx/html/meta/

# Expose port 80 (HTTP)
EXPOSE 80

# nginx runs automatically, but let's be explicit
CMD ["nginx", "-g", "daemon off;"]