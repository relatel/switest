# frozen_string_literal: true

module Switest
  # Constants used throughout the library.
  module Constants
    # FreeSWITCH ESL event names
    module Events
      CHANNEL_CREATE = "CHANNEL_CREATE"
      CHANNEL_ANSWER = "CHANNEL_ANSWER"
      CHANNEL_HANGUP = "CHANNEL_HANGUP"
      CHANNEL_HANGUP_COMPLETE = "CHANNEL_HANGUP_COMPLETE"
      CHANNEL_EXECUTE_COMPLETE = "CHANNEL_EXECUTE_COMPLETE"
      CHANNEL_ORIGINATE = "CHANNEL_ORIGINATE"
      HEARTBEAT = "HEARTBEAT"

      # Events to subscribe to by default
      DEFAULT_SUBSCRIPTIONS = [
        CHANNEL_CREATE,
        CHANNEL_ANSWER,
        CHANNEL_HANGUP,
        CHANNEL_HANGUP_COMPLETE,
        CHANNEL_EXECUTE_COMPLETE,
        CHANNEL_ORIGINATE
      ].freeze
    end

    # ESL content types
    module ContentTypes
      AUTH_REQUEST = "auth/request"
      COMMAND_REPLY = "command/reply"
      API_RESPONSE = "api/response"
      EVENT_PLAIN = "text/event-plain"
    end

    # SIP response codes
    module SipCodes
      OK = "200"
      RINGING = "180"
      SESSION_PROGRESS = "183"
      BUSY = "486"
      DECLINE = "603"
      SERVER_ERROR = "500"
      SERVICE_UNAVAILABLE = "503"
    end

    # Call hangup causes
    module HangupCauses
      NORMAL_CLEARING = "NORMAL_CLEARING"
      USER_BUSY = "USER_BUSY"
      NO_ANSWER = "NO_ANSWER"
      CALL_REJECTED = "CALL_REJECTED"
      ORIGINATOR_CANCEL = "ORIGINATOR_CANCEL"
      NORMAL_TEMPORARY_FAILURE = "NORMAL_TEMPORARY_FAILURE"
    end

    # Call directions
    module Directions
      INBOUND = "inbound"
      OUTBOUND = "outbound"
    end

    # Call states
    module CallStates
      OFFERED = :offered
      ANSWERED = :answered
      ENDED = :ended
    end

    # Default configuration values
    module Defaults
      HOST = "127.0.0.1"
      PORT = 8021
      PASSWORD = "ClueCon"
      COMMAND_TIMEOUT = 5
      CALL_TIMEOUT = 30
    end
  end
end
