require_relative '../spec_helper'

module Vendorificator
  describe Segment do
    describe '#work_dir' do
      it 'includes vendor group' do
        env = basic_environment
        env.stubs(:relative_root_dir)
        env.git.stubs(:git_work_tree)
        categorized = Vendor.new(env, 'test', group: 'group').segment
        uncategorized = Vendor.new(env, 'test').segment

        assert { categorized.work_dir.include? 'group' }
        deny { uncategorized.work_dir.include? 'group' }
      end
    end

    describe '#head' do
      let(:seg) { Vendor.new(basic_environment, 'test').segment }
      let(:rev_parse) { basic_environment.git.capturing.expects(:rev_parse).with({:verify => true, :quiet => true}, "refs/heads/vendor/test") }
      it "returns SHA1 of segment's head" do
        rev_parse.returns "a2745fdf2d7e51f139f9417c5ca045b389fa939f\n"
        head = seg.head
        assert { head == 'a2745fdf2d7e51f139f9417c5ca045b389fa939f' }
      end

      it "returns nil when segment's branch does not exist" do
        rev_parse.raises MiniGit::GitError
        head = seg.head
        assert { head.nil? }
      end
    end

    describe '#branch_name' do
      it 'includes vendor group' do
        uncategorized = Vendor.new(basic_environment, 'test').segment
        categorized = Vendor.new(basic_environment, 'test', group: 'group').segment

        deny { uncategorized.branch_name.include? 'group' }
        assert { categorized.branch_name.include? 'group' }
      end
    end

    describe '#pushable_refs' do
      let(:environment) do
        Environment.new(Thor::Shell::Basic.new) do
          vendor :nginx, :group => :cookbooks
          vendor :nginx_simplecgi, :group => :cookbooks
        end
      end

      before do
        environment.git.capturing.stubs(:show_ref).returns <<EOF
a2745fdf2d7e51f139f9417c5ca045b389fa939f refs/heads/master
127eb134185e2bf34c79321819b81f8464392d45 refs/heads/vendor/cookbooks/nginx
0448bfa569d3d94dcb3e485c8da60fdb33d365f6 refs/heads/vendor/cookbooks/nginx_simplecgi
a2745fdf2d7e51f139f9417c5ca045b389fa939f refs/remotes/origin/master
127eb134185e2bf34c79321819b81f8464392d45 refs/remotes/origin/vendor/cookbooks/nginx
0448bfa569d3d94dcb3e485c8da60fdb33d365f6 refs/remotes/origin/vendor/cookbooks/nginx_simplecgi
e4646a83e6d24322958e1d7a2ed922dae034accd refs/tags/vendor/cookbooks/nginx/1.2.0
fa0293b914420f59f8eb4c347fb628dcb953aad3 refs/tags/vendor/cookbooks/nginx/1.3.0
680dee5e56a0d49ba2ae299bb82189b6f2660c9b refs/tags/vendor/cookbooks/nginx_simplecgi/0.1.0
EOF
        environment.load_vendorfile
      end

      it 'includes all own refs' do
        refs = environment['nginx'].pushable_refs
        assert { refs.include? 'refs/heads/vendor/cookbooks/nginx' }
        assert { refs.include? 'refs/tags/vendor/cookbooks/nginx/1.2.0' }
        assert { refs.include? 'refs/tags/vendor/cookbooks/nginx/1.3.0' }

        refs = environment['nginx_simplecgi'].pushable_refs
        assert { refs.include? 'refs/heads/vendor/cookbooks/nginx_simplecgi' }
        assert { refs.include? 'refs/tags/vendor/cookbooks/nginx_simplecgi/0.1.0' }
      end

      it "doesn't include other modules' refs" do
        refs = environment['nginx'].pushable_refs
        deny { refs.include? 'refs/tags/vendor/cookbooks/nginx_simplecgi/0.1.0' }
      end
    end

    describe '#included_in_list?' do
      let(:segment) do
        Vendor.new(basic_environment, 'test_name', :group => 'test_group').segment
      end

      it 'finds a module by name' do
        assert { segment.included_in_list?(['test_name']) }
      end

      it 'finds a module by qualified name' do
        assert { segment.included_in_list?(['test_group/test_name']) }
      end

      it 'finds a module by path' do
        segment.stubs(:work_dir).returns('./vendor/test_group/test_name')

        assert { segment.included_in_list?(['./vendor/test_group/test_name']) }
      end

      it 'finds a module by merge commit' do
        segment.stubs(:merged_base).returns('foobar')
        segment.stubs(:work_dir).returns('abc/def')

        assert { segment.included_in_list?(['foobar']) }
      end

      it 'finds a module by branch name' do
        segment.stubs(:merged_base).returns('abcdef')
        segment.stubs(:work_dir).returns('abc/def')
        segment.stubs(:branch_name).returns('foo/bar')

        assert { segment.included_in_list?(['foo/bar']) }
      end

    end

  end
end

