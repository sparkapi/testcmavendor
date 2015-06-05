KEY_CONFIG = YAML::load(File.read("#{Rails.root}/config/keys.yml"))[Rails.env]
AWS_KEYS = YAML::load(File.read("#{Rails.root}/config/aws_keys.yml"))[Rails.env]
