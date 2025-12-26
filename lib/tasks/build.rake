# ref: https://github.com/rails/rails/issues/43906#issuecomment-1094380699
# https://github.com/rails/rails/issues/43906#issuecomment-1099992310
task before_assets_precompile: :environment do
  # Ensure NODE_OPTIONS is set for all Node.js processes
  # Use environment variable if set, otherwise use default
  node_options = ENV['NODE_OPTIONS'] || '--max-old-space-size=10240 --openssl-legacy-provider'
  
  # Export NODE_OPTIONS so all child processes inherit it
  ENV['NODE_OPTIONS'] = node_options

  # run a command which starts your packaging
  system("NODE_OPTIONS='#{node_options}' pnpm install")
  system('echo "-------------- Bulding SDK for Production --------------"')
  system("NODE_OPTIONS='#{node_options}' pnpm run build:sdk")
  system('echo "-------------- Bulding App for Production --------------"')
end

# every time you execute 'rake assets:precompile'
# run 'before_assets_precompile' first
Rake::Task['assets:precompile'].enhance %w[before_assets_precompile]
