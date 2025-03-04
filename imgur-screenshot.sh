#!/bin/bash
# https://github.com/jomo/imgur-screenshot
# https://imgur.com/tools

if [ "${1}" = "--debug" ]; then
  echo "########################################"
  echo "Enabling debug mode"
  echo "Please remove credentials before pasting"
  echo "########################################"
  echo ""
  uname -a
  for arg in ${0} "${@}"; do
    echo -n "'${arg}' "
  done
  echo -e "\n"
  shift
  set -x
fi

current_version="v1.7.4"

function is_mac() {
  uname | grep -q "Darwin"
}

### IMGUR-SCREENSHOT DEFAULT CONFIG ####

# You can override the config in ~/.config/imgur-screenshot/settings.conf

imgur_anon_id="ea6c0ef2987808e"
imgur_icon_path="${HOME}/imgur.png"

imgur_acct_key=""
imgur_secret=""
login="false"
album_title=""
album_id=""
credentials_file="${HOME}/.config/imgur-screenshot/credentials.conf"

file_name_format="imgur-%Y_%m_%d-%H:%M:%S.png" # when using scrot, must end with .png!
file_dir="${HOME}"

upload_connect_timeout="5"
upload_timeout="120"
upload_retries="1"

if is_mac; then
  screenshot_select_command="screencapture -i %img"
  screenshot_window_command="screencapture -iWa %img"
  screenshot_full_command="screencapture %img"
  open_command="open %url"
else
  screenshot_select_command="scrot -s %img"
  screenshot_window_command="scrot %img"
  screenshot_full_command="scrot %img"
  open_command="xdg-open %url"
fi
open="true"

mode="select"
edit_command="gimp %img"
edit="false"
exit_on_album_creation_fail="true"

log_file="${HOME}/.imgur-screenshot.log"

auto_delete=""
copy_url="true"
keep_file="true"
check_update="true"

# NOTICE: if you make changes here, also edit the docs at
# https://github.com/jomo/imgur-screenshot/wiki/Config

# You can override the config in ~/.config/imgur-screenshot/settings.conf

############## END CONFIG ##############

settings_path="${HOME}/.config/imgur-screenshot/settings.conf"
if [ -f "${settings_path}" ]; then
  source "${settings_path}"
fi

# dependency check
if [ "${1}" = "--check" ]; then
  (which grep &>/dev/null && echo "OK: found grep") || echo "ERROR: grep not found"
  if is_mac; then
    if which growlnotify &>/dev/null; then
      echo "OK: found growlnotify"
    elif which terminal-notifier &>/dev/null; then
      echo "OK: found terminal-notifier"
    else
      echo "ERROR: growlnotify nor terminal-notifier found"
    fi
    (which screencapture &>/dev/null && echo "OK: found screencapture") || echo "ERROR: screencapture not found"
    (which pbcopy &>/dev/null && echo "OK: found pbcopy") || echo "ERROR: pbcopy not found"
  else
    (which notify-send &>/dev/null && echo "OK: found notify-send") || echo "ERROR: notify-send (from libnotify-bin) not found"
    (which scrot &>/dev/null && echo "OK: found scrot") || echo "ERROR: scrot not found"
    (which xclip &>/dev/null && echo "OK: found xclip") || echo "ERROR: xclip not found"
  fi
  (which curl &>/dev/null && echo "OK: found curl") || echo "ERROR: curl not found"
  exit 0
fi


# notify <'ok'|'error'> <title> <text>
function notify() {
  if is_mac; then
    if which growlnotify &>/dev/null; then
      growlnotify  --icon "${imgur_icon_path}" --iconpath "${imgur_icon_path}" --title "${2}" --message "${3}"
    else
      terminal-notifier -appIcon "${imgur_icon_path}" -contentImage "${imgur_icon_path}" -title "imgur: ${2}" -message "${3}"
    fi
  else
    if [ "${1}" = "error" ]; then
      notify-send -a ImgurScreenshot -u critical -c "im.error" -i "${imgur_icon_path}" -t 500 "imgur: ${2}" "${3}"
    else
      notify-send -a ImgurScreenshot -u low -c "transfer.complete" -i "${imgur_icon_path}" -t 500 "imgur: ${2}" "${3}"
    fi
  fi
}

function take_screenshot() {
  echo "Please select area"
  is_mac || sleep 0.1 # https://bbs.archlinux.org/viewtopic.php?pid=1246173#p1246173

  cmd="screenshot_${mode}_command"
  cmd=${!cmd//\%img/${1}}

  shot_err="$(${cmd} &>/dev/null)" #takes a screenshot with selection
  if [ "${?}" != "0" ]; then
    echo "Failed to take screenshot '${1}': '${shot_err}'. For more information visit https://github.com/jomo/imgur-screenshot/wiki/Troubleshooting" | tee -a "${log_file}"
    notify error "Something went wrong :(" "Information has been logged"
    exit 1
  fi
}

function check_for_update() {
  # exit non-zero on HTTP error, output only the body (no stats) but output errors, follow redirects, output everything to stdout
  remote_version="$(curl --compressed -fsSL --stderr - "https://api.github.com/repos/jomo/imgur-screenshot/releases" | egrep -m 1 --color 'tag_name":\s*".*"' | cut -d '"' -f 4)"
  if [ "${?}" -eq "0" ]; then
    if [ ! "${current_version}" = "${remote_version}" ] && [ ! -z "${current_version}" ] && [ ! -z "${remote_version}" ]; then
      echo "Update found!"
      echo "Version ${remote_version} is available (You have ${current_version})"
      notify ok "Update found" "Version ${remote_version} is available (You have ${current_version}). https://github.com/jomo/imgur-screenshot"
      echo "Check https://github.com/jomo/imgur-screenshot/releases/${remote_version} for more info."
    elif [ -z "${current_version}" ] || [ -z "${remote_version}" ]; then
      echo "Invalid empty version string"
      echo "Current (local) version: '${current_version}'"
      echo "Latest (remote) version: '${remote_version}'"
    else
      echo "Version ${current_version} is up to date."
    fi
  else
    echo "Failed to check for latest version: ${remote_version}"
  fi
}

function check_oauth2_client_secrets() {
  if [ -z "${imgur_acct_key}" ] || [ -z "${imgur_secret}" ]; then
    echo "In order to upload to your account, register a new application at:"
    echo "https://api.imgur.com/oauth2/addclient"
    echo "Select 'OAuth 2 authorization without a callback URL'"
    echo "Then, set the imgur_acct_key (Client ID) and imgur_secret in your config."
    exit 1
  fi
}

function load_access_token() {
  token_expire_time=0
  # check for saved access_token and its expiration date
  if [ -f "${credentials_file}" ]; then
    source "${credentials_file}"
  fi
  current_time="$(date +%s)"
  preemptive_refresh_time="$((10*60))"
  expired="$((current_time > (token_expire_time - preemptive_refresh_time)))"
  if [ ! -z "${refresh_token}" ]; then
    # token already set
    if [ "${expired}" -eq "0" ]; then
      # token expired
      refresh_access_token "${credentials_file}"
    fi
  else
    acquire_access_token "${credentials_file}"
  fi
}

function acquire_access_token() {
  check_oauth2_client_secrets
  # prompt for a PIN
  authorize_url="https://api.imgur.com/oauth2/authorize?client_id=${imgur_acct_key}&response_type=pin"
  echo "Go to"
  echo "${authorize_url}"
  echo "and grant access to this application."
  read -rp "Enter the PIN: " imgur_pin

  if [ -z "${imgur_pin}" ]; then
    echo "PIN not entered, exiting"
    exit 1
  fi

  # exchange the PIN for access token and refresh token
  response="$(curl --compressed -fsSL --stderr - \
    -F "client_id=${imgur_acct_key}" \
    -F "client_secret=${imgur_secret}" \
    -F "grant_type=pin" \
    -F "pin=${imgur_pin}" \
    https://api.imgur.com/oauth2/token)"
  save_access_token "${response}" "${1}"
}

function refresh_access_token() {
  check_oauth2_client_secrets
  token_url="https://api.imgur.com/oauth2/token"
  # exchange the refresh token for access_token and refresh_token
  response="$(curl --compressed -fsSL --stderr - -F "client_id=${imgur_acct_key}" -F "client_secret=${imgur_secret}" -F "grant_type=refresh_token" -F "refresh_token=${refresh_token}" "${token_url}")"
  if [ ! "${?}" -eq "0" ]; then
    # curl failed
    handle_upload_error "${response}" "${token_url}"
    exit 1
  fi
  save_access_token "${response}" "${1}"
}

function save_access_token() {
  if ! grep -q "access_token" <<<"${1}"; then
    # server did not send access_token
    echo "Error: Something is wrong with your credentials:"
    echo "${1}"
    exit 1
  fi

  access_token="$(egrep -o 'access_token":".*"' <<<"${1}" | cut -d '"' -f 3)"
  refresh_token="$(egrep -o 'refresh_token":".*"' <<<"${1}" | cut -d '"' -f 3)"
  expires_in="$(egrep -o 'expires_in":[0-9]*' <<<"${1}" | cut -d ':' -f 2)"
  token_expire_time="$(( $(date +%s) + expires_in ))"

  # create dir if not exist
  mkdir -p "$(dirname "${2}")" 2>/dev/null
  touch "${2}" && chmod 600 "${2}"
  cat <<EOF > "${2}"
access_token="${access_token}"
refresh_token="${refresh_token}"
token_expire_time="${token_expire_time}"
EOF
}

function fetch_account_info() {
  response="$(curl --compressed --connect-timeout "${upload_connect_timeout}" -m "${upload_timeout}" --retry "${upload_retries}" -fsSL --stderr - -H "Authorization: Bearer ${access_token}" https://api.imgur.com/3/account/me)"
  if egrep -q '"success":\s*true' <<<"${response}"; then
    username="$(egrep -o '"url":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    echo "Logged in as ${username}."
    echo "https://${username}.imgur.com"
  else
    echo "Failed to fetch info: ${response}"
  fi
}

function delete_image() {
  response="$(curl --compressed -X DELETE  -fsSL --stderr - -H "Authorization: Client-ID ${1}" "https://api.imgur.com/3/image/${2}")"
  if egrep -q '"success":\s*true' <<<"${response}"; then
    echo "Image successfully deleted (delete hash: ${2})." >> "${3}"
  else
    echo "The Image could not be deleted: ${response}." >> "${3}"
  fi
}

function upload_authenticated_image() {
  echo "Uploading '${1}'..."
  title="$(echo "${1}" | rev | cut -d "/" -f 1 | cut -d "." -f 2- | rev)"
  if [ -n "${album_id}" ]; then
    response="$(curl --compressed --connect-timeout "${upload_connect_timeout}" -m "${upload_timeout}" --retry "${upload_retries}" -fsSL --stderr - -F "title=${title}" -F "image=@\"${1}\"" -F "album=${album_id}" -H "Authorization: Bearer ${access_token}" https://api.imgur.com/3/image)"
  else
    response="$(curl --compressed --connect-timeout "${upload_connect_timeout}" -m "${upload_timeout}" --retry "${upload_retries}" -fsSL --stderr - -F "title=${title}" -F "image=@\"${1}\"" -H "Authorization: Bearer ${access_token}" https://api.imgur.com/3/image)"
  fi

  # JSON parser premium edition (not really)
  if egrep -q '"success":\s*true' <<<"${response}"; then
    img_id="$(egrep -o '"id":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    img_ext="$(egrep -o '"link":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4 | rev | cut -d "." -f 1 | rev)" # "link" itself has ugly '\/' escaping and no https!
    del_id="$(egrep -o '"deletehash":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"

    if [ ! -z "${auto_delete}" ]; then
      export -f delete_image
      echo "Deleting image in ${auto_delete} seconds."
      nohup /bin/bash -c "sleep ${auto_delete} && delete_image ${imgur_anon_id} ${del_id} ${log_file}" &
    fi

    handle_upload_success "https://i.imgur.com/${img_id}.${img_ext}" "https://imgur.com/delete/${del_id}" "${1}"
  else # upload failed
    err_msg="$(egrep -o '"error":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    test -z "${err_msg}" && err_msg="${response}"
    handle_upload_error "${err_msg}" "${1}"
  fi
}

function upload_anonymous_image() {
  echo "Uploading '${1}'..."
  title="$(echo "${1}" | rev | cut -d "/" -f 1 | cut -d "." -f 2- | rev)"
  if [ -n "${album_id}" ]; then
    response="$(curl --compressed --connect-timeout "${upload_connect_timeout}" -m "${upload_timeout}" --retry "${upload_retries}" -fsSL --stderr - -H "Authorization: Client-ID ${imgur_anon_id}" -F "title=${title}" -F "image=@\"${1}\"" -F "album=${album_id}" https://api.imgur.com/3/image)"
  else
    response="$(curl --compressed --connect-timeout "${upload_connect_timeout}" -m "${upload_timeout}" --retry "${upload_retries}" -fsSL --stderr - -H "Authorization: Client-ID ${imgur_anon_id}" -F "title=${title}" -F "image=@\"${1}\"" https://api.imgur.com/3/image)"
  fi
  # JSON parser premium edition (not really)
  if egrep -q '"success":\s*true' <<<"${response}"; then
    img_id="$(egrep -o '"id":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    img_ext="$(egrep -o '"link":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4 | rev | cut -d "." -f 1 | rev)" # "link" itself has ugly '\/' escaping and no https!
    del_id="$(egrep -o '"deletehash":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"

    if [ ! -z "${auto_delete}" ]; then
      export -f delete_image
      echo "Deleting image in ${auto_delete} seconds."
      nohup /bin/bash -c "sleep ${auto_delete} && delete_image ${imgur_anon_id} ${del_id} ${log_file}" &
    fi

    handle_upload_success "https://i.imgur.com/${img_id}.${img_ext}" "https://imgur.com/delete/${del_id}" "${1}"
  else # upload failed
    err_msg="$(egrep -o '"error":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    test -z "${err_msg}" && err_msg="${response}"
    handle_upload_error "${err_msg}" "${1}"
  fi
}

function handle_upload_success() {
  echo ""
  echo "image  link: ${1}"
  echo "delete link: ${2}"

  if [ "${copy_url}" = "true" ] && [ -z "${album_title}" ]; then
    if is_mac; then
      echo -n "${1}" | pbcopy
    else
      echo -n "${1}" | xclip -selection clipboard
    fi
    echo "URL copied to clipboard"
  fi

  # print to log file: image link, image location, delete link
  echo -e "${1}\t${3}\t${2}" >> "${log_file}"

  notify ok "Upload done!" "${1}"

  if [ ! -z "${open_command}" ] && [ "${open}" = "true" ]; then
    open_cmd=${open_command//\%url/${1}}
    open_cmd=${open_cmd//\%img/${2}}
    echo "Opening '${open_cmd}'"
    eval "${open_cmd}"
  fi
}

function handle_upload_error() {
  error="Upload failed: \"${1}\""
  echo "${error}"
  echo -e "Error\t${2}\t${error}" >> "${log_file}"
  notify error "Upload failed :(" "${1}"
}

function handle_album_creation_success() {
  echo ""
  echo "Album  link: ${1}"
  echo "Delete hash: ${2}"
  echo ""

  notify ok "Album created!" "${1}"

  if [ "${copy_url}" = "true" ]; then
    if is_mac; then
      echo -n "${1}" | pbcopy
    else
      echo -n "${1}" | xclip -selection clipboard
    fi
    echo "URL copied to clipboard"
  fi

  # print to log file: album link, album title, delete hash
  echo -e "${1}\t\"${3}\"\t${2}" >> "${log_file}"
}

function handle_album_creation_error() {
  error="Album creation failed: \"${1}\""
  echo -e "Error\t${2}\t${error}" >> "${log_file}"
  notify error "Album creation failed :(" "${1}"
  if [ ${exit_on_album_creation_fail} ]; then
    exit 1
  fi
}

while [ ${#} != 0 ]; do
  case "${1}" in
  -h | --help)
    echo "usage: ${0} [--debug] [-c | --check | -v | -h | -u]"
    echo "       ${0} [--debug] [option]... [file]..."
    echo ""
    echo "      --debug                  Enable debugging, must be first option"
    echo "  -h, --help                   Show this help, exit"
    echo "  -v, --version                Show current version, exit"
    echo "      --check                  Check if all dependencies are installed, exit"
    echo "  -c, --connect                Show connected imgur account, exit"
    echo "  -o, --open <true|false>      Override 'open' config"
    echo "  -e, --edit <true|false>      Override 'edit' config"
    echo "  -i, --edit-command <command> Override 'edit_command' config (include '%img'), sets --edit 'true'"
    echo "  -l, --login <true|false>     Override 'login' config"
    echo "  -a, --album <album_title>    Create new album and upload there"
    echo "  -A, --album-id <album_id>    Override 'album_id' config"
    echo "  -k, --keep-file <true|false> Override 'keep_file' config"
    echo "  -d, --auto-delete <s>        Automatically delete image after <s> seconds"
    echo "  -u, --update                 Check for updates, exit"
    echo "  file                         Upload file instead of taking a screenshot"
    exit 0;;
  -v | --version)
    echo "${current_version}"
    exit 0;;
  -s | --select)
    mode="select"
    shift;;
  -w | --window)
    mode="window"
    shift;;
  -f | --full)
    mode="full"
    shift;;
  -o | --open)
    open="${2}"
    shift 2;;
  -e | --edit)
    edit="${2}"
    shift 2;;
  -i | --edit-command)
    edit_command="${2}"
    edit="true"
    shift 2;;
  -l | --login)
    login="${2}"
    shift 2;;
  -c | --connect)
    load_access_token
    fetch_account_info
    exit 0;;
  -a | --album)
    album_title="${2}"
    shift 2;;
  -A | --album-id)
    album_id="${2}"
    shift 2;;
  -k | --keep-file)
    keep_file="${2}"
    shift 2;;
  -d | --auto-delete)
    auto_delete="${2}"
    shift 2;;
  -u | --update)
    check_for_update
    exit 0;;
  *)
    upload_files=("${@}")
    break;;
  esac
done

if [ "${login}" = "true" ]; then
  # load before changing directory
  load_access_token
fi


if [ -n "${album_title}" ]; then
  if [ "${login}" = "true" ]; then
    response="$(curl -fsSL --stderr - \
      -F "title=${album_title}" \
      -H "Authorization: Bearer ${access_token}" \
      https://api.imgur.com/3/album)"
  else
    response="$(curl -fsSL --stderr - \
      -F "title=${album_title}" \
      -H "Authorization: Client-ID ${imgur_anon_id}" \
      https://api.imgur.com/3/album)"
  fi
  if egrep -q '"success":\s*true' <<<"${response}"; then # Album creation successful
    echo "Album '${album_title}' successfully created"
    album_id="$(egrep -o '"id":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    del_id="$(egrep -o '"deletehash":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    handle_album_creation_success "http://imgur.com/a/${album_id}" "${del_id}" "${album_title}"

    if [ "${login}" = "false" ]; then
      album_id="${del_id}"
    fi
  else # Album creation failed
    err_msg="$(egrep -o '"error":\s*"[^"]+"' <<<"${response}" | cut -d "\"" -f 4)"
    test -z "${err_msg}" && err_msg="${response}"
    handle_album_creation_error "${err_msg}" "${album_title}"
  fi
fi

if [ -z "${upload_files}" ]; then
  upload_files[0]=""
fi

for upload_file in "${upload_files[@]}"; do

  if [ -z "${upload_file}" ]; then
    cd "${file_dir}" || exit 1

    # new filename with date
    img_file="$(date +"${file_name_format}")"
    take_screenshot "${img_file}"
  else
    # upload file instead of screenshot
    img_file="${upload_file}"
  fi

  # get full path
  img_file="$(cd "$( dirname "${img_file}")" && echo "$(pwd)/$(basename "${img_file}")")"

  # check if file exists
  if [ ! -f "${img_file}" ]; then
    echo "file '${img_file}' doesn't exist !"
    exit 1
  fi

  # open image in editor if configured
  if [ "${edit}" = "true" ]; then
    edit_cmd=${edit_command//\%img/${img_file}}
    echo "Opening editor '${edit_cmd}'"
    if ! (eval "${edit_cmd}"); then
      echo "Error for image '${img_file}': command '${edit_cmd}' failed, not uploading. For more information visit https://github.com/jomo/imgur-screenshot/wiki/Troubleshooting" | tee -a "${log_file}"
      notify error "Something went wrong :(" "Information has been logged"
      exit 1
    fi
  fi

  if [ "${login}" = "true" ]; then
    upload_authenticated_image "${img_file}"
  else
    upload_anonymous_image "${img_file}"
  fi

  # delete file if configured
  if [ "${keep_file}" = "false" ] && [ -z "${1}" ]; then
    echo "Deleting temp file ${file_dir}/${img_file}"
    rm -rf "${img_file}"
  fi

  echo ""
done


if [ "${check_update}" = "true" ]; then
  check_for_update
fi
