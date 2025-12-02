# frozen_string_literal: true

# Require blather/client/dsl instead of blather/client to avoid the CLI parser
require "blather/client/dsl"

module Switest
  module Rayo
    RAYO_NS = "urn:xmpp:rayo:1"
    OUTPUT_NS = "urn:xmpp:rayo:output:1"

    # Base class for Rayo IQ commands
    class Command < Blather::Stanza::Iq
      def self.new(to = nil)
        node = super(:set)
        node.to = to if to
        node
      end
    end

    # Dial command - initiates outbound call
    # <iq type="set"><dial xmlns="urn:xmpp:rayo:1" to="..." from="..."/></iq>
    class Dial < Command
      register :rayo_dial, :dial, RAYO_NS

      def self.new(to_uri, from_uri = nil, headers = {})
        node = super()
        dial_node = Nokogiri::XML::Node.new("dial", node.document)
        dial_node.default_namespace = RAYO_NS
        dial_node["to"] = to_uri
        dial_node["from"] = from_uri if from_uri
        headers.each do |name, value|
          header = Nokogiri::XML::Node.new("header", node.document)
          header["name"] = name.to_s
          header["value"] = value.to_s
          dial_node << header
        end
        node << dial_node
        node
      end

      def dial_node
        find_first("//ns:dial", ns: RAYO_NS)
      end
    end

    # Answer command - answers an offered call
    # <iq type="set"><answer xmlns="urn:xmpp:rayo:1"/></iq>
    class Answer < Command
      register :rayo_answer, :answer, RAYO_NS

      def self.new(call_jid)
        node = super(call_jid)
        answer_node = Nokogiri::XML::Node.new("answer", node.document)
        answer_node.default_namespace = RAYO_NS
        node << answer_node
        node
      end
    end

    # Hangup command - terminates a call
    # <iq type="set"><hangup xmlns="urn:xmpp:rayo:1"/></iq>
    class Hangup < Command
      register :rayo_hangup, :hangup, RAYO_NS

      def self.new(call_jid, headers = {})
        node = super(call_jid)
        hangup_node = Nokogiri::XML::Node.new("hangup", node.document)
        hangup_node.default_namespace = RAYO_NS
        headers.each do |name, value|
          header = Nokogiri::XML::Node.new("header", node.document)
          header["name"] = name.to_s
          header["value"] = value.to_s
          hangup_node << header
        end
        node << hangup_node
        node
      end
    end

    # Reject command - rejects an offered call before answering
    # <iq type="set"><reject xmlns="urn:xmpp:rayo:1"><reason/></reject></iq>
    class Reject < Command
      register :rayo_reject, :reject, RAYO_NS

      REASONS = %i[busy decline error].freeze

      def self.new(call_jid, reason = :decline, headers = {})
        node = super(call_jid)
        reject_node = Nokogiri::XML::Node.new("reject", node.document)
        reject_node.default_namespace = RAYO_NS

        reason_node = Nokogiri::XML::Node.new(reason.to_s, node.document)
        reason_node.default_namespace = RAYO_NS
        reject_node << reason_node

        headers.each do |name, value|
          header = Nokogiri::XML::Node.new("header", node.document)
          header["name"] = name.to_s
          header["value"] = value.to_s
          reject_node << header
        end
        node << reject_node
        node
      end
    end

    # Output command - plays audio on a call (used for DTMF tones)
    # <iq type="set"><output xmlns="urn:xmpp:rayo:output:1">...</output></iq>
    class Output < Command
      register :rayo_output, :output, OUTPUT_NS

      def self.new(call_jid, ssml_or_url)
        node = super(call_jid)
        output_node = Nokogiri::XML::Node.new("output", node.document)
        output_node.default_namespace = OUTPUT_NS

        document_node = Nokogiri::XML::Node.new("document", node.document)
        document_node["content-type"] = "application/ssml+xml"
        document_node.content = ssml_or_url
        output_node << document_node

        node << output_node
        node
      end
    end

    # Offer presence - received when an inbound call arrives
    # <presence from="call@server"><offer xmlns="urn:xmpp:rayo:1" to="..." from="..."/></presence>
    class Offer < Blather::Stanza::Presence
      register :rayo_offer, :offer, RAYO_NS

      def call_id
        from.node
      end

      def call_jid
        from
      end

      def to_uri
        offer_node["to"]
      end

      def from_uri
        offer_node["from"]
      end

      def headers
        offer_node.xpath("ns:header", ns: RAYO_NS).each_with_object({}) do |h, hash|
          hash[h["name"]] = h["value"]
        end
      end

      private

      def offer_node
        find_first("//ns:offer", ns: RAYO_NS)
      end
    end

    # Answered presence - received when a call is answered
    # <presence from="call@server"><answered xmlns="urn:xmpp:rayo:1"/></presence>
    class Answered < Blather::Stanza::Presence
      register :rayo_answered, :answered, RAYO_NS

      def call_id
        from.node
      end

      def call_jid
        from
      end
    end

    # Ringing presence - received when remote party is ringing
    # <presence from="call@server"><ringing xmlns="urn:xmpp:rayo:1"/></presence>
    class Ringing < Blather::Stanza::Presence
      register :rayo_ringing, :ringing, RAYO_NS

      def call_id
        from.node
      end

      def call_jid
        from
      end
    end

    # End presence - received when a call ends
    # <presence from="call@server" type="unavailable"><end xmlns="urn:xmpp:rayo:1"><reason/></end></presence>
    class End < Blather::Stanza::Presence
      register :rayo_end, :end, RAYO_NS

      REASONS = %i[hangup hangup_command timeout busy reject redirect error].freeze

      def call_id
        from.node
      end

      def call_jid
        from
      end

      def reason
        return nil unless end_node

        REASONS.each do |r|
          reason_str = r.to_s.tr("_", "-")
          return r if end_node.xpath("ns:#{reason_str}", ns: RAYO_NS).any?
        end
        :unknown
      end

      private

      def end_node
        find_first("//ns:end", ns: RAYO_NS)
      end
    end
  end
end
