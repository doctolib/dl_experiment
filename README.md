# dl_experiment

A lightweight scientist-like framework to refactor critical paths.

## Requirements

- Ruby 2.3+

## Usage

Just drop this line in your Gemfile:

```rb
gem 'dl_experiment'
```

Let's consider the following method we'd like to refactor:

```rb
def allows?(user)
  model.check_user?(user).valid?
end
```

If we'd like to use cancancan, we could add the following experiment:

```rb
def allows?(user)
  Experiment.protocol('cancancan') do |e|
    e.legacy      { model.check_user?(user).valid? }  # old way
    e.experiment  { user.can?(:read, model) }         # new way
  end
end
```

Your code will still return the same thing (or raise the same exception), but, from now on, assuming you are using rails, your test suite will fail if there is a single time where both implementations are not returning the same thing.

More interesting: you can trigger a code block when there is a difference and log it the way you'd like:

```rb
def allows?(user)
  Experiment.protocol('cancancan') do |e|
    e.legacy      { model.check_user?(user).valid? }  # old way
    e.experiment  { user.can?(:read, model) }         # new way

    e.on_diff do |legacy, experiment|
      Rails.logger.warn(
        "[Experiment][User:#{user}] Results not equals: " +
        "#{legacy.value} != #{experiment.value}"
      )
    end
  end
end
```

This will allow you to compare, even in production, some code implementation.

*Warning:* Be careful with side effects. You don't want to create twice the same data in your database in production. Don't experiment on non-functional code.

## Motivation

Sometimes, you'd like to change some code you don't fully understand and that is not fully covered by your tests.

This tool, like scientist (the framework from github), is made to help you do that, but with a smaller integration cost.

## Feature set


## Runnings tests

```bash
bundle
rspec
```

## Authors

- [Alexandre Ignjatovic](https://github.com/bankair)

## License

[MIT](https://github.com/doctolib/dl_experiment/blob/master/LICENSE) © [Doctolib](https://github.com/doctolib/)

## Additional resources

Alternatives:

- https://github.com/github/scientist
- https://github.com/testdouble/suture

