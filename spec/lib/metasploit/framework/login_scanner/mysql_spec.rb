require 'spec_helper'
require 'metasploit/framework/login_scanner/mysql'

describe Metasploit::Framework::LoginScanner::MySQL do
  let(:public) { 'root' }
  let(:private) { 'toor' }
  let(:pub_blank) {
    Metasploit::Framework::LoginScanner::Credential.new(
        paired: true,
        public: public,
        private: ''
    )
  }

  let(:pub_pub) {
    Metasploit::Framework::LoginScanner::Credential.new(
        paired: true,
        public: public,
        private: public
    )
  }

  let(:pub_pri) {
    Metasploit::Framework::LoginScanner::Credential.new(
        paired: true,
        public: public,
        private: private
    )
  }

  subject(:login_scanner) { described_class.new }

  it_behaves_like 'Metasploit::Framework::LoginScanner::Base'
  it_behaves_like 'Metasploit::Framework::LoginScanner::RexSocket'

  context '#attempt_login' do

    context 'when the attempt is successful' do
      it 'returns a result object with a status of :success' do
        ::RbMysql.should_receive(:connect).and_return "fake mysql handle"
        expect(login_scanner.attempt_login(pub_pri).status).to eq :success
      end
    end

    context 'when the attempt is unsuccessful' do
      context 'due to connection refused' do
        it 'returns a result with a status of :connection_error' do
          ::RbMysql.should_receive(:connect).and_raise Errno::ECONNREFUSED
          expect(login_scanner.attempt_login(pub_pub).status).to eq :connection_error
        end

        it 'returns a result with the proof containing an appropriate error message' do
          ::RbMysql.should_receive(:connect).and_raise Errno::ECONNREFUSED
          expect(login_scanner.attempt_login(pub_pub).proof).to eq "Connection refused"
        end
      end

      context 'due to connection timeout' do
        it 'returns a result with a status of :connection_error' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::ClientError
          expect(login_scanner.attempt_login(pub_pub).status).to eq :connection_error
        end

        it 'returns a result with the proof containing an appropriate error message' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::ClientError
          expect(login_scanner.attempt_login(pub_pub).proof).to eq "Connection timeout"
        end
      end

      context 'due to operation timeout' do
        it 'returns a result with a status of :connection_error' do
          ::RbMysql.should_receive(:connect).and_raise Errno::ETIMEDOUT
          expect(login_scanner.attempt_login(pub_pub).status).to eq :connection_error
        end

        it 'returns a result with the proof containing an appropriate error message' do
          ::RbMysql.should_receive(:connect).and_raise Errno::ETIMEDOUT
          expect(login_scanner.attempt_login(pub_pub).proof).to eq "Operation Timed out"
        end
      end

      context 'due to not being allowed to connect from this host' do
        it 'returns a result with a status of :connection_error' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::HostNotPrivileged, "Host not privileged"
          expect(login_scanner.attempt_login(pub_pub).status).to eq :connection_error
        end

        it 'returns a result with the proof containing an appropriate error message' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::HostNotPrivileged, "Host not privileged"
          expect(login_scanner.attempt_login(pub_pub).proof).to eq "Unable to login from this host due to policy"
        end
      end

      context 'due to access denied' do
        it 'returns a result with a status of :failed' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::AccessDeniedError, "Access Denied"
          expect(login_scanner.attempt_login(pub_pub).status).to eq :failed
        end

        it 'returns a result with the proof containing an appropriate error message' do
          ::RbMysql.should_receive(:connect).and_raise RbMysql::AccessDeniedError, "Access Denied"
          expect(login_scanner.attempt_login(pub_pub).proof).to eq "Access Denied"
        end
      end
    end
  end

end