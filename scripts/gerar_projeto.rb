# Gera AgendALLS.xcodeproj a partir dos arquivos em AgendALLS/.
# Uso: gem install xcodeproj && ruby scripts/gerar_projeto.rb
require 'xcodeproj'

raiz = File.expand_path('..', __dir__)
Dir.chdir(raiz)
caminho = 'AgendALLS.xcodeproj'
FileUtils.rm_rf(caminho)

proj = Xcodeproj::Project.new(caminho)
proj.root_object.development_region = 'pt-BR'
proj.root_object.known_regions = ['pt-BR', 'Base']

alvo = proj.new_target(:application, 'AgendALLS', :osx, '14.0')
grupo = proj.main_group.new_group('AgendALLS', 'AgendALLS')

def grupo_para(grupo_raiz, partes)
  partes.reduce(grupo_raiz) do |g, nome|
    g.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == nome } || g.new_group(nome, nome)
  end
end

Dir.glob('AgendALLS/**/*.swift').sort.each do |arquivo|
  partes = arquivo.split('/')[1..-2]
  ref = grupo_para(grupo, partes).new_file(File.basename(arquivo))
  alvo.source_build_phase.add_file_reference(ref)
end

assets = grupo.new_file('Assets.xcassets')
alvo.resources_build_phase.add_file_reference(assets)

alvo.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = 'AgendALLS'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'br.andres.agendalls'
  s['MARKETING_VERSION'] = '0.3.0'
  s['CURRENT_PROJECT_VERSION'] = '3'
  s['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  s['SWIFT_VERSION'] = '5.0'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'AgendALLS'
  s['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.productivity'
  s['INFOPLIST_KEY_NSHumanReadableCopyright'] = 'Desenvolvido por André S.'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['COMBINE_HIDPI_IMAGES'] = 'YES'
  s['ENABLE_HARDENED_RUNTIME'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  s['OTHER_LDFLAGS'] = ['$(inherited)', '-lsqlite3']
  # Assinatura local gratuita: roda no próprio Mac sem conta de desenvolvedor.
  s['CODE_SIGN_STYLE'] = 'Manual'
  s['CODE_SIGN_IDENTITY'] = '-'
  s['DEVELOPMENT_TEAM'] = ''
  s.delete('INFOPLIST_FILE')
end

esquema = Xcodeproj::XCScheme.new
esquema.add_build_target(alvo)
esquema.set_launch_target(alvo)
esquema.archive_action.build_configuration = 'Release'
proj.save
esquema.save_as(caminho, 'AgendALLS', true)
puts "Projeto gerado: #{caminho}"
