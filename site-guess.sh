#!/usr/bin/env bash
set -o pipefail

# Site config guess for gogomonia
# Check some common site configurations:
# - Qrator
# - site is alias
# - https random paths
# - redirect from random paths

main() {
  # SITE='' # Site domain

  parse_args "$@" || (usage && exit 1)

  if [ -z "$SITE" ] ; then
    echo -e "SITENAME is required!\n\n" && usage && exit 1
  fi

#  exit 1

  site_guess
}

usage() {
printf " Usage: $0 SITENAME

    SITENAME
            Site domain for testing

    --help|-h
            Print this message
"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --help|-h)
        return 1
        ;;
      --alias)
        ALIAS="$2"
        shift
        ;;
      --*)
        echo "Illegal option $1"
        return 1
        ;;
      *)
        SITE="$1"
        shift
        ;;
    esac
    shift $(( $# > 0 ? 1 : 0 ))
  done
}

site_guess() {
  REPORT_FILE="./report_$SITE.log"

  AUTO_MAIN=yes
  AUTO_HTTPS=no
  REDIRECT_ALIAS=
  CHECK_REDIRECTS_FROM_RND=


  URL_HTTP_MAIN="http://$SITE/"
  URL_HTTP_RND="http://$SITE/randomPath"
  URL_HTTPS_MAIN="https://$SITE/"
  URL_HTTPS_RND="https://$SITE/randomPath"

  CURL_HEADERS=

  header Проверки главной страницы $SITE

  msg "  Запрос главной по http: $URL_HTTP_MAIN"

  curl_request $URL_HTTP_MAIN
  if [[ $CURL_EXIT != "0" ]] ; then
    msg $CURL_ERROR
    exit 1
  fi

  msg_log "  Заголовки ответа:"
  msg_log "$CURL_HEADERS"

  case "$CURL_STATUS" in
    200)
      AUTO_MAIN="true"
      msg "    Главная отвечает $CURL_STATUS"
      msg "    Можно включать автопроверку главной: main: true"
      ;;
    30*)
      msg "    Главная отвечает перенаправлением на $CURL_LOCATION"

      if [[ $REDIR_SCHEME == "https" && $REDIR_DOMAIN == $SITE && $REDIR_PATH == "/" ]] ; then
         msg "    http перенаправляет на https, возможны режимы https: redirect или strict"
         AUTO_MAIN="true"
         AUTO_HTTPS="redirect"
      else
        AUTO_MAIN="false"
        if [[ $REDIR_DOMAIN != $SITE ]] ; then
          # $AUTO_ALIAS=$SITE
          msg "    http перенаправляет на другой домен: ${REDIR_DOMAIN}"
          msg "    Нужно описывать сайт ${REDIR_DOMAIN}, а ${SITE} добавить в redirectAliases"
          if [[ $ALIAS == "" ]] ; then
            ./$0 --alias $SITE $REDIR_DOMAIN
            exit 0
          fi
          SITE_IS_ALIAS=yes
        else
          msg "    Такое перенаправление не поддерживается автопроверками,"
          msg "    нужно описать тесты специально для этого сайта."
        fi
      fi
      ;;
    *)
      AUTO_MAIN="false"
      msg "    Главная отвечает $CURL_STATUS"
      msg "    Автопроверки не работают с таким статусом,"
      msg "    нужно описать тесты специально для этого сайта."
      ;;
  esac


  msg "  Запрос главной по https: $URL_HTTPS_MAIN"

  curl_request $URL_HTTPS_MAIN
  if [[ $CURL_EXIT != "0" ]] ; then
    msg $CURL_ERROR
    exit 1
  fi

  msg_log "  Заголовки ответа:"
  msg_log "$CURL_HEADERS"

  case "$CURL_STATUS" in
    200)
      msg "    Главная по https отвечает $CURL_STATUS"
      if [[ $AUTO_MAIN == "true" ]] ; then
        if [[ $AUTO_HTTPS == "no" ]] ; then
          msg "    http не редиректит на https, https отдаёт страницу сразу."
          msg "    Подходит автопроверка https: optional"
          AUTO_HTTPS=optional
        fi
        if [[ $AUTO_HTTPS == "redirect" ]] ; then
          msg "    http редиректит на https, https отдаёт страницу сразу."
          if [[ $CURL_HSTS == "" ]] ; then
            msg "    Подходит автопроверка https: redirect"
          else
            msg "    В ответе присутствует заголовок ${CURL_HSTS}"
            msg "    Подходит автопроверка https: strict"
            AUTO_HTTPS="strict"
          fi
        fi
      else
        msg "    http не отдаёт страницу сразу и не редиректит на https"
        msg "    Нужно описать тесты специально для этого сайта."
        AUTO_HTTPS="no"
      fi
      ;;
    30*)
      msg "    Главная по https перенаправляет на $CURL_LOCATION"
      if [[ $REDIR_DOMAIN != $SITE ]] ; then
        msg "    https перенаправляет на другой домен: ${REDIR_DOMAIN}"
        msg "    Нужно описывать сайт ${REDIR_DOMAIN}, а ${SITE} добавить в redirectAliases"
        SITE_IS_ALIAS=yes
      else
        msg "    Такое перенаправление не поддерживается автопроверками,"
        msg "    нужно описать тесты специально для этого сайта."
      fi
      AUTO_HTTPS="no"
      ;;
    *)
      msg "    Главная по https отвечает $CURL_STATUS"
      msg "    Автопроверки для https не работают с таким статусом,"
      msg "    нужно описать тесты специально для этого сайта."
      AUTO_HTTPS="no"
      ;;
  esac


  header "Конфиг автопроверок для $SITE"

  msg "sites:"
  msg "- site: $SITE"
  if [[ $ALIAS != "" ]] ; then
    msg "  redirectAliases:"
    msg "  - $ALIAS"
  fi
  msg "  auto:"
  msg "    mainPage: $AUTO_MAIN"
  msg "    https: $AUTO_HTTPS"



#  header "Проверки рандомных путей для ${SITE}"
#
#  msg "Запрос рандомного пути по http: $URL_HTTP_RND"
#
#  curl_request $URL_HTTP_RND
#
#  msg_log "Заголовки ответа:"
#  msg_log "$CURL_HEADERS"
#
#  case "$CURL_STATUS" in
#    20*)
#      msg "  Несуществующий путь отвечает $CURL_STATUS"
#      ;;
#    30*)
#      msg "  Несуществующий путь перенаправлением на $CURL_LOCATION"
#      ;;
#    *)
#      msg "  Несуществующий путь отвечает $CURL_STATUS"
#      msg "  Автопроверки несуществующего пути не работают с таким статусом"
#      ;;
#  esac
#  echo "$CURL_HEADERS"

  msg ""
  msg "Полный лог в файле $REPORT_FILE"
}

curl_request() {
  tmpl=site-guess-XXXXX
  curlResponse=$(mktemp -t $tmpl)
  curlHeaders=$(mktemp -t $tmpl)
  curlError=$(mktemp -t $tmpl)
  CURL_STATUS=$(curl -sS -w %{http_code} \
    -o $curlResponse \
    -D $curlHeaders \
    --max-redirs 0 \
    --connect-timeout 3 \
    --max-time 10 \
    --request GET \
    $1 2>$curlError
  )
  CURL_EXIT=$?

  CURL_RESPONSE=$(cat $curlResponse 2>/dev/null)
  CURL_HEADERS=$(cat $curlHeaders 2>/dev/null)
  CURL_ERROR=$(cat $curlError 2>/dev/null)
  CURL_LOCATION=$(grep Location $curlHeaders | sed s/Location:\ // | sed 's/\r//')
  if [[ $CURL_LOCATION != "" ]] ; then
    REDIR_SCHEME=${CURL_LOCATION%%://*}
    REDIR_DOMAIN=$(echo ${CURL_LOCATION} | sed -r 's/https?:\/\/([^\/]+)(\/[^\/]*)*/\1/' )
    REDIR_PATH=$(echo ${CURL_LOCATION} | sed -r 's/https?:\/\/([^\/]+)((\/[^\/]*)*)/\2/' )
  fi
  CURL_HSTS=$(grep 'Strict-Transport-Security: ' $curlHeaders)

  rm $curlResponse
  rm $curlHeaders
  rm $curlError
}

msg() {
  echo "$@" | tee -a $REPORT_FILE
}

msg_log() {
  echo "$@" >> $REPORT_FILE
}

header() {
  echo -e "\n\n$@\n" | tee -a $REPORT_FILE
}


main "$@"
