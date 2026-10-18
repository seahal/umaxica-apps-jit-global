# frozen_string_literal: true

# Writes every feature declared in FeatureFlags into the Flipper store.
#
# Declaring a flag in the registry does not create it in Flipper. An unwritten
# feature still reads correctly -- the polarity decides what "unset" means -- but
# it is invisible in the Flipper UI, so an operator reaching for a kill switch
# during an incident finds an empty list, and every read logs "Could not find
# feature". Registering makes the switch present and its default state explicit.
#
# `Flipper.add` creates the feature without enabling it, so this is safe to run
# against any environment: it never changes a state an operator has chosen, and
# it never turns a suspension switch on. Run it after `db:migrate` on a new
# environment, and again after adding a row to the registry.
namespace :feature_flags do
  desc "Create every registered feature in Flipper without changing any state"
  task register: :environment do
    existing = Flipper.features.map { |feature| feature.key.to_sym }

    FeatureFlags.names.each do |name|
      if existing.include?(name)
        puts "#{name}: present"
      else
        Flipper.add(name)
        puts "#{name}: created"
      end
    end
  end

  desc "Show every registered feature with its polarity and current state"
  task status: :environment do
    FeatureFlags::REGISTRY.each_value do |flag|
      state = FeatureFlags.enabled?(flag.name) ? "on" : "off"
      puts format("%-34s %-13s %s", flag.name, flag.polarity, state)
    end
  end
end
