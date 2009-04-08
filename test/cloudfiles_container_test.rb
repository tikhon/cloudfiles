require File.dirname(__FILE__) + '/test_helper'

class CloudfilesContainerTest < Test::Unit::TestCase
  
  def test_object_creation
    connection = mock(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    response = {'x-container-bytes-used' => '42', 'x-container-object-count' => '5'}
    response.stubs(:code).returns('204')
    connection.stubs(:cfreq => response)
    @container = CloudFiles::Container.new(connection, 'test_container')
    assert_equal @container.name, 'test_container'
    assert_equal @container.class, CloudFiles::Container
    assert_equal @container.public?, true
  end
  
  def test_object_creation_no_such_container
    connection = mock(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    response = {'x-container-bytes-used' => '42', 'x-container-object-count' => '5'}
    response.stubs(:code).returns('999')
    connection.stubs(:cfreq => response)
    assert_raise(NoSuchContainerException) do
      @container = CloudFiles::Container.new(connection, 'test_container')
    end
  end
  
  def test_object_creation_no_cdn
    connection = mock(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    response = {'x-container-bytes-used' => '42', 'x-container-object-count' => '5'}
    response.stubs(:code).returns('204').then.returns('999')
    connection.stubs(:cfreq => response)
    @container = CloudFiles::Container.new(connection, 'test_container')
    assert_equal @container.name, 'test_container'
    assert_equal @container.cdn_enabled, false
    assert_equal @container.public?, false
  end
  
  def test_to_s
    build_net_http_object
    assert_equal @container.to_s, 'test_container'
  end
  
  def test_make_private_succeeds
    build_net_http_object(:code => '201')
    assert_nothing_raised do
      @container.make_private
    end
  end
  
  def test_make_private_fails
    build_net_http_object(:code => '999')
    assert_raises(NoSuchContainerException) do
      @container.make_private
    end
  end
  
  def test_make_public_succeeds
    build_net_http_object(:code => '201')
    assert_nothing_raised do
      @container.make_public
    end
  end
  
  def test_make_public_fails
    build_net_http_object(:code => '999')
    assert_raises(NoSuchContainerException) do
      @container.make_public
    end
  end
  
  def test_empty_is_false
    connection = mock(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    response = {'x-container-bytes-used' => '42', 'x-container-object-count' => '5'}
    response.stubs(:code).returns('204')
    connection.stubs(:cfreq => response)
    @container = CloudFiles::Container.new(connection, 'test_container')
    assert_equal @container.empty?, false
  end
  
  def test_empty_is_true
    connection = mock(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    response = {'x-container-bytes-used' => '0', 'x-container-object-count' => '0'}
    response.stubs(:code).returns('204')
    connection.stubs(:cfreq => response)
    @container = CloudFiles::Container.new(connection, 'test_container')
    assert_equal @container.empty?, true
  end
  
  def test_object_fetch
    build_net_http_object(:code => '204', :response => {'last-modified' => 'Wed, 28 Jan 2009 16:16:26 GMT'})
    object = @container.object('good_object')
    assert_equal object.class, CloudFiles::StorageObject
  end
  
  def test_create_object
    build_net_http_object()
    object = @container.create_object('new_object')
    assert_equal object.class, CloudFiles::StorageObject
  end
  
  def test_object_exists_true
    build_net_http_object
    assert_equal @container.object_exists?('good_object'), true
  end
  
  def test_object_exists_false
    build_net_http_object(:code => '999')
    assert_equal @container.object_exists?('bad_object'), false
  end
  
  def test_delete_object_succeeds
    build_net_http_object
    assert_nothing_raised do
      @container.delete_object('good_object')
    end
  end
  
  def test_delete_invalid_object_fails
    build_net_http_object(:code => '404')
    assert_raise(NoSuchObjectException) do
      @container.delete_object('nonexistent_object')
    end
  end
  
  def test_delete_invalid_response_code_fails
    build_net_http_object(:code => '999')
    assert_raise(InvalidResponseException) do
      @container.delete_object('broken_object')
    end
  end
  
  def test_fetch_objects
    build_net_http_object(:code => '200', :body => "foo\nbar\nbaz")
    objects = @container.objects
    assert_equal objects.class, Array
    assert_equal objects.size, 3
    assert_equal objects.first, 'foo'
  end
  
  def test_fetch_object_detail
    body = %{<?xml version="1.0" encoding="UTF-8"?>
    <container name="video">
    <object><name>kisscam.mov</name><hash>96efd5a0d78b74cfe2a911c479b98ddd</hash><bytes>9196332</bytes><content_type>video/quicktime</content_type><last_modified>2008-12-18T10:34:43.867648</last_modified></object>
    <object><name>penaltybox.mov</name><hash>d2a4c0c24d8a7b4e935bee23080e0685</hash><bytes>24944966</bytes><content_type>video/quicktime</content_type><last_modified>2008-12-18T10:35:19.273927</last_modified></object>
    </container>
    }
    build_net_http_object(:code => '200', :body => body)
    details = @container.objects_detail
    assert_equal details.size, 2
    assert_equal details['kisscam.mov'][:bytes], '9196332'
  end
  
  def test_fetch_object_detail_empty
    build_net_http_object
    details = @container.objects_detail
    assert_equal details, {}
  end
  
  def test_fetch_object_detail_error
    build_net_http_object(:code => '999')
    assert_raise(InvalidResponseException) do
      details = @container.objects_detail
    end
  end
  
  private
  
  def build_net_http_object(args={:code => '204' })
    CloudFiles::Container.any_instance.stubs(:populate).returns(true)
    connection = stub(:storagehost => 'test.storage.example', :storagepath => '/dummy/path', :cdnmgmthost => 'cdm.test.example', :cdnmgmtpath => '/dummy/path')
    args[:response] = {} unless args[:response]
    response = {'x-cdn-management-url' => 'http://cdn.example.com/path', 'x-storage-url' => 'http://cdn.example.com/storage', 'authtoken' => 'dummy_token', 'last-modified' => Time.now.to_s}.merge(args[:response])
    response.stubs(:code).returns(args[:code])
    response.stubs(:body).returns args[:body] || nil
    connection.stubs(:cfreq => response)
    #server = mock()
    #server.stubs(:verify_mode= => true)
    #server.stubs(:start => true)
    #server.stubs(:use_ssl=).returns(true)
    #server.stubs(:get).returns(response)
    #server.stubs(:post).returns(response)
    #server.stubs(:put).returns(response)
    #server.stubs(:head).returns(response)
    #server.stubs(:delete).returns(response)
    #Net::HTTP.stubs(:new).returns(server)
    @container = CloudFiles::Container.new(connection, 'test_container')
    @container.stubs(:connection).returns(connection)
  end
  
  
end