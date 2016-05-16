# encoding: UTF-8
require 'spec_helper'

describe OpenToken do

  #"renew-until"=>"2010-03-05T07:19:15Z"
  #"not-before"=>"2010-03-04T19:19:15Z"
  #"not-on-or-after"=>"2010-03-04T19:24:15Z"
  describe ".decode" do

    before do
      OpenToken.password = 'Test123'
    end

    context "with an aes-128-cbc token with a subject attribute" do
      let(:opentoken) { "T1RLAQJ0Ca97sl6MLJAZDa_hdFzMlicMQBDjqUzrXl0EOXKmpj5oo7L5AACgaWoW8fZizrsLbtxb_F00aTdFmhw8flGy4iGqPWPtqYpdIzQZzg5WvrvYH8Rnq7ckJpYk2YPZw6yNyA4ohG-BgFdTHc0U7CwZTFmodg1MuO0cTh7T98s2RXiTcaZa21MNO0yuXKm2Q10cbrWhnB5yHJUhSHx6JLxlgMTZ0oE0DoUOB6JmoLMYHcyL9hKRiPTh62ky_QmXRaifDNOdl4sH2w**" }
      context "when current time is between expiration dates" do
        subject(:token) do
          result = nil
          Timecop.freeze(Time.iso8601('2010-03-04T19:20:10Z')) do
            result = OpenToken.decode opentoken
          end
          result
        end

        it "decrypts subject from token payload" do
          expect(token[:subject]).to eq 'john@example.com'
        end

        it "decrypts subject using string or symbol" do
          expect(token['subject']).to eq 'john@example.com'
        end

        it "parses 'renew-until' date" do
          expect(token.valid_until).to eq Time.iso8601('2010-03-05T07:19:15Z')
        end
      end
      context "when current time is outside clock skew tolerance before expiration date" do
        it do
          Timecop.freeze(Time.iso8601('2010-03-04T19:19:05Z')) do
            expect { OpenToken.decode opentoken }.to raise_error OpenToken::TokenExpiredError
          end
        end
      end
      context "when current time is within clock skew tolerance before expiration date" do
        it do
          Timecop.freeze(Time.iso8601('2010-03-04T19:19:11Z')) do
            expect { OpenToken.decode opentoken }.to_not raise_error
          end
        end
      end
    end

    context "with a token with an attribute value containing an apostrophe" do
      subject(:token) do
        result = nil
        Timecop.freeze(Time.iso8601('2011-01-13T11:08:02Z')) do
          result = OpenToken.decode("T1RLAQLIjiqgexqi1PQcEKCetvGoSYR2jhDFSIfE5ctlSBxEnq3S1ydjAADQUNRIKJx6_14aE3MQZnDABupGJrKNfoJHFS5VOnKexjMtboeOgst31Hf-D9CZBrpB7Jv0KBwnQ7DN3HizecPT76oX3UGtq_Vi5j5bKYCeObYm9W6h7NY-VzcZY5TTqIuulc2Jit381usAWZ2Sv1c_CWwhrH4hw-x7vUQMSjErvXK1qvsrFCpfNr7XlArx0HjI6kT5XEaHgQNdC0zrLw9cZ4rewoEisR3H5oM7B6gMaP82wTSFVBXvpn5r0KT-Iuc3JuG2en1zVh3GNf110oQCKQ**")
        end
        result
      end

      it "preserves the apostrophe" do
        expect(token[:last_name]).to eq "D'angelo"
      end
    end

    context "with a nil token" do
      it { expect { OpenToken.decode(nil) }.to raise_error OpenToken::TokenInvalidError }
    end

  end

  describe ".encode" do
    before { OpenToken.password = 'Password1' }

    ciphers = {
      aes_128_cbc: OpenToken::Cipher::AES_128_CBC,
      aes_256_cbc: OpenToken::Cipher::AES_256_CBC,
      des_168_cbc: OpenToken::Cipher::DES3_168_CBC,
    }

    ciphers.each do |cipher_name, cipher|
      let(:encoded) { OpenToken.encode(attributes_in, cipher) }
      let(:decoded) { OpenToken.decode(encoded) }

      context "using #{cipher_name}" do
        context 'a large payload' do
          let(:chars) { ('A'..'z').to_a }

          def random_chars(n)
            n.times.map { chars.sample }.join
          end

          def huge_attrs(key_value_pairs, chars_per)
            keys = key_value_pairs.times.map { random_chars(chars_per) }
            values = key_value_pairs.times.map { random_chars(chars_per) }
            Hash[keys.zip(values)]
          end

          let(:attributes_in) { huge_attrs(100, 100) }
          it { expect(decoded).to eq attributes_in }
        end

        context 'a medium payload' do
          let(:attributes_in) { { 'abcdefghijklmnopqrstuvwxyz1234567890' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890', '0987654321ZYXWVUTSRQPONMLKJIHGFEDCBA' => '0987654321zyxwvutsrqponmlkjihgfedcba' } }
          it { expect(decoded).to eq attributes_in }
        end

        context "with non-ascii utf-8 values" do
          let(:attributes_in) { { "subject" => "André", "email" => "john@example.com" } }
          it { expect(decoded).to eq attributes_in }
        end
      end
    end

  end
end
