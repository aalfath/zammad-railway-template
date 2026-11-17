# Runs on every start, after zammad-init. Keeps the URL settings in step with the service
# variables and, on the very first start, creates the admin with Zammad's own auto wizard,
# so the public URL never shows an open setup page that a stranger could claim.
Setting.set('fqdn', ENV['ZAMMAD_FQDN']) if ENV['ZAMMAD_FQDN'].present?
Setting.set('http_type', ENV['ZAMMAD_HTTP_TYPE']) if ENV['ZAMMAD_HTTP_TYPE'].present?

if User.admin_user_exists?(except_user_id: [1])
  puts 'railway-template: admin exists, setup skipped'
  exit
end

email = ENV['ZAMMAD_ADMIN_EMAIL'].to_s.strip
password = ENV['ZAMMAD_ADMIN_PASSWORD'].to_s
abort 'railway-template: ZAMMAD_ADMIN_EMAIL is empty; set it to create the admin' if email.empty?
abort 'railway-template: ZAMMAD_ADMIN_PASSWORD is empty' if password.empty?
org = ENV['ZAMMAD_ORGANIZATION'].presence || 'My Company'

File.write(Rails.root.join('auto_wizard.json'), {
  'TextModuleLocale' => { 'Locale' => 'en-us' },
  'Organizations'    => [{ 'name' => org }],
  'Users'            => [{
    'login'        => email,
    'email'        => email,
    'firstname'    => 'Admin',
    'lastname'     => 'User',
    'organization' => org,
    'password'     => password,
  }],
  'Settings'         => [
    { 'name' => 'organization', 'value' => org },
  ],
}.to_json)
AutoWizard.setup
Setting.set('system_init_done', true)
puts "railway-template: created the admin account #{email}"
