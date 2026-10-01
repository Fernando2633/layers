#!/bin/sh
# Convierte la DATABASE_URL de Render (postgresql://user:pass@host:port/db)
# al formato JDBC que usa Spring Boot y arranca la app.
# Variables opcionales:
#   DB_SCHEMA -> schema propio dentro de la BD (para compartir una sola BD entre varias apps)
set -e

RAW_URL="$(printf "%s" "${DATABASE_URL:-$DB_URL}" | tr -d "[:space:]\"'")"
EXTRA_OPTS=""

if [ -n "$RAW_URL" ]; then
  case "$RAW_URL" in
    jdbc:*)
      JDBC_URL="$RAW_URL"
      ;;
    postgres://*|postgresql://*)
      REST="${RAW_URL#*://}"
      CREDS="${REST%@*}"
      HOSTDB="${REST##*@}"
      export SPRING_DATASOURCE_USERNAME="${CREDS%%:*}"
      export SPRING_DATASOURCE_PASSWORD="${CREDS#*:}"
      JDBC_URL="jdbc:postgresql://${HOSTDB}"
      ;;
    *)
      echo "==> Formato de DATABASE_URL no reconocido"
      exit 1
      ;;
  esac

  # Si vienen usuario/password por separado, tienen prioridad
  [ -n "$DB_USERNAME" ] && export SPRING_DATASOURCE_USERNAME="$DB_USERNAME"
  [ -n "$DB_USER" ] && export SPRING_DATASOURCE_USERNAME="$DB_USER"
  [ -n "$DB_PASSWORD" ] && export SPRING_DATASOURCE_PASSWORD="$DB_PASSWORD"

  if [ -n "$DB_SCHEMA" ]; then
    case "$JDBC_URL" in
      *\?*) JDBC_URL="${JDBC_URL}&currentSchema=${DB_SCHEMA}" ;;
      *)    JDBC_URL="${JDBC_URL}?currentSchema=${DB_SCHEMA}" ;;
    esac
    EXTRA_OPTS="-Dspring.jpa.properties.hibernate.default_schema=${DB_SCHEMA} -Dspring.jpa.properties.hibernate.hbm2ddl.create_namespaces=true"
  fi

  export SPRING_DATASOURCE_URL="$JDBC_URL"
  export SPRING_DATASOURCE_DRIVER_CLASS_NAME="org.postgresql.Driver"
  export SPRING_JPA_DATABASE_PLATFORM="org.hibernate.dialect.PostgreSQLDialect"
  export SPRING_H2_CONSOLE_ENABLED="false"
  export SPRING_SQL_INIT_MODE="never"
  echo "==> Usando PostgreSQL (schema: ${DB_SCHEMA:-public})"
else
  echo "==> Sin DATABASE_URL, se usa la config local de application.properties"
fi

exec java $JAVA_OPTS $EXTRA_OPTS -jar app.jar
