module Vendorificator
  class Commit
    attr_reader :git

    # Public: Initializes the object
    #
    # rev - The String containing revision expression for this commit.
    # git - The MiniGit instance to use.
    #
    # Returns Commit object.
    def initialize(rev, git)
      @rev = rev
      @git = git
    end

    # Public: Finds branches that contain this commit.
    #
    # Returns Array of branch names.
    def branches
      git.capturing.branch({:contains => true}, @rev).split("\n").map do |name|
        name.tr('*', '').strip
      end
    end

    # Public: Checks if such a commit exists in the repository.
    #
    # Returns boolean.
    def exists?
      git.capturing.rev_parse(@rev)
      return true
    rescue MiniGit::GitError
      false
    end

  end
end