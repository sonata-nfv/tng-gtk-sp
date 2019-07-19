## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
class AddWimUuidAndVlId < ActiveRecord::Migration[5.2]
  def change
    add_column :infrastructure_requests, :bidirectional, :boolean
    add_column :infrastructure_requests, :egress, :string
    add_column :infrastructure_requests, :ingress, :string
    add_column :infrastructure_requests, :qos, :string, default: default: ''
    add_column :infrastructure_requests, :vl_id, :string
    add_column :infrastructure_requests, :wim_uuid, :string
  end
end
